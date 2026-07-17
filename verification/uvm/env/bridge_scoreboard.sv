`uvm_analysis_imp_decl(_cxl)
`uvm_analysis_imp_decl(_ucie)

// Protocol-accurate, payload- and ordering-aware scoreboard.
//
// Model (mirrors the RTL):
//   * C2U: each accepted CXL request predicts one translated UCIe egress flit.
//     The egress arbiter reorders posted ahead of non-posted, so predictions
//     are held in per-class queues and matched by the class of the emerging
//     flit. A write header is followed by ceil(len/2) payload beats routed to
//     that class's payload FIFO; payload content is checked in order per class.
//   * U2C: each accepted UCIe completion predicts one translated CXL egress
//     flit (single in-order queue). SC completions carry payload beats.
//
// Beats are classified header-vs-payload by mirror counters that decode the
// same length fields the RTL uses, so the scoreboard stays in lockstep with
// the DUT regardless of how the stimulus paces beats.

class bridge_scoreboard extends uvm_scoreboard;
  uvm_analysis_imp_cxl #(bridge_item, bridge_scoreboard) cxl_export;
  uvm_analysis_imp_ucie#(bridge_item, bridge_scoreboard) ucie_export;

  // Predicted egress headers (data + trailing payload-beat count).
  bridge_item c2u_posted_exp[$];
  bridge_item c2u_np_exp[$];
  bridge_item u2c_exp[$];

  // Expected payload-beat content, per physical stream.
  bit [63:0] c2u_posted_pl[$];
  bit [63:0] c2u_np_pl[$];
  bit [63:0] u2c_pl[$];

  // Ingress header/payload mirror counters.
  int  cxl_in_pl_cnt;   bit cxl_in_pl_posted;
  int  ucie_in_pl_cnt;
  // Egress header/payload mirror counters.
  int  ucie_out_pl_cnt; bit ucie_out_pl_posted;
  int  cxl_out_pl_cnt;

  // Statistics.
  int c2u_hdr_checked, u2c_hdr_checked;
  int c2u_pl_checked,  u2c_pl_checked;
  int errors;

  `uvm_component_utils(bridge_scoreboard)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cxl_export  = new("cxl_export",  this);
    ucie_export = new("ucie_export", this);
  endfunction

  // Build a lightweight prediction record.
  function bridge_item make_pred(bit [63:0] data, int pl_beats);
    bridge_item p = bridge_item::type_id::create("pred");
    p.data     = data;
    p.pl_beats = pl_beats;
    return p;
  endfunction

  function void err(string msg);
    errors++;
    `uvm_error("SB", msg)
  endfunction

  // ---- CXL-side monitor: cxl_in requests (ingress) + cxl_out completions (egress) ----
  virtual function void write_cxl(bridge_item item);
    if (!item.is_egress) begin
      // CXL ingress: request header, then its write payload beats.
      if (cxl_in_pl_cnt == 0) begin
        bridge_item pred = make_pred(predict_ucie_from_cxl(item.data),
                                     c2u_payload_len(item.data));
        if (is_posted_cxl(item.data)) c2u_posted_exp.push_back(pred);
        else                          c2u_np_exp.push_back(pred);
        cxl_in_pl_cnt    = c2u_payload_len(item.data);
        cxl_in_pl_posted = is_posted_cxl(item.data);
        `uvm_info("SB", $sformatf("C2U req in: %h -> pred %h (pl=%0d)",
                  item.data, pred.data, pred.pl_beats), UVM_HIGH)
      end else begin
        if (cxl_in_pl_posted) c2u_posted_pl.push_back(item.data);
        else                  c2u_np_pl.push_back(item.data);
        cxl_in_pl_cnt--;
      end
    end else begin
      // CXL egress: completion header, then its payload beats.
      if (cxl_out_pl_cnt == 0) begin
        if (u2c_exp.size() == 0)
          err($sformatf("U2C egress with no prediction: %h", item.data));
        else begin
          bridge_item exp = u2c_exp.pop_front();
          if (item.data !== exp.data)
            err($sformatf("U2C header mismatch: exp %h got %h", exp.data, item.data));
          else u2c_hdr_checked++;
          cxl_out_pl_cnt = exp.pl_beats;
        end
      end else begin
        if (u2c_pl.size() == 0)
          err($sformatf("U2C payload beat with no expected data: %h", item.data));
        else begin
          bit [63:0] e = u2c_pl.pop_front();
          if (item.data !== e)
            err($sformatf("U2C payload mismatch: exp %h got %h", e, item.data));
          else u2c_pl_checked++;
        end
        cxl_out_pl_cnt--;
      end
    end
  endfunction

  // ---- UCIe-side monitor: ucie_in completions (ingress) + ucie_out requests (egress) ----
  virtual function void write_ucie(bridge_item item);
    if (!item.is_egress) begin
      // UCIe ingress: completion header, then its SC payload beats.
      if (ucie_in_pl_cnt == 0) begin
        bridge_item pred = make_pred(predict_cxl_from_ucie(item.data),
                                     u2c_payload_len(item.data));
        u2c_exp.push_back(pred);
        ucie_in_pl_cnt = u2c_payload_len(item.data);
        `uvm_info("SB", $sformatf("U2C cpl in: %h -> pred %h (pl=%0d)",
                  item.data, pred.data, pred.pl_beats), UVM_HIGH)
      end else begin
        u2c_pl.push_back(item.data);
        ucie_in_pl_cnt--;
      end
    end else begin
      // UCIe egress: request header (posted/np reordered), then payload beats.
      if (ucie_out_pl_cnt == 0) begin
        bit posted = is_ucie_posted(item.data);
        if (posted) begin
          if (c2u_posted_exp.size() == 0)
            err($sformatf("C2U posted egress with no prediction: %h", item.data));
          else begin
            bridge_item exp = c2u_posted_exp.pop_front();
            if (item.data !== exp.data)
              err($sformatf("C2U posted header mismatch: exp %h got %h", exp.data, item.data));
            else c2u_hdr_checked++;
            ucie_out_pl_cnt = exp.pl_beats;
          end
        end else begin
          if (c2u_np_exp.size() == 0)
            err($sformatf("C2U np egress with no prediction: %h", item.data));
          else begin
            bridge_item exp = c2u_np_exp.pop_front();
            if (item.data !== exp.data)
              err($sformatf("C2U np header mismatch: exp %h got %h", exp.data, item.data));
            else c2u_hdr_checked++;
            ucie_out_pl_cnt = exp.pl_beats;
          end
        end
        ucie_out_pl_posted = posted;
      end else begin
        if (ucie_out_pl_posted) begin
          if (c2u_posted_pl.size() == 0)
            err($sformatf("C2U posted payload with no expected data: %h", item.data));
          else begin
            bit [63:0] e = c2u_posted_pl.pop_front();
            if (item.data !== e)
              err($sformatf("C2U posted payload mismatch: exp %h got %h", e, item.data));
            else c2u_pl_checked++;
          end
        end else begin
          if (c2u_np_pl.size() == 0)
            err($sformatf("C2U np payload with no expected data: %h", item.data));
          else begin
            bit [63:0] e = c2u_np_pl.pop_front();
            if (item.data !== e)
              err($sformatf("C2U np payload mismatch: exp %h got %h", e, item.data));
            else c2u_pl_checked++;
          end
        end
        ucie_out_pl_cnt--;
      end
    end
  endfunction

  // ---- End-of-test drain + verdict ----
  function void check_phase(uvm_phase phase);
    int leftover;
    super.check_phase(phase);
    leftover = c2u_posted_exp.size() + c2u_np_exp.size() + u2c_exp.size() +
               c2u_posted_pl.size()  + c2u_np_pl.size()  + u2c_pl.size();
    if (leftover != 0)
      err($sformatf("unmatched at end: c2u_posted=%0d c2u_np=%0d u2c=%0d pl(p/np/u2c)=%0d/%0d/%0d",
          c2u_posted_exp.size(), c2u_np_exp.size(), u2c_exp.size(),
          c2u_posted_pl.size(), c2u_np_pl.size(), u2c_pl.size()));
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", $sformatf(
      "checked C2U hdr=%0d pl=%0d | U2C hdr=%0d pl=%0d | errors=%0d",
      c2u_hdr_checked, c2u_pl_checked, u2c_hdr_checked, u2c_pl_checked, errors),
      UVM_LOW)
    if (errors == 0)
      `uvm_info("SB", "SCOREBOARD PASS", UVM_LOW)
    else
      `uvm_error("SB", $sformatf("SCOREBOARD FAIL: %0d error(s)", errors))
  endfunction

endclass
