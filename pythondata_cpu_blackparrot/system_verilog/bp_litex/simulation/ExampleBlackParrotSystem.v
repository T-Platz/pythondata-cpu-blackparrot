/*
 * Name:
 *  ExampleBlackParrotSystem.v
 *
 * Description:
 *  A top level module for integrating the
 *  BlackParrot unicore lite into LiteX.
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bsg_wb_defines.svh"

module ExampleBlackParrotSystem
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  import bp_me_pkg::*;
  import bsg_noc_pkg::*;
  import bsg_wb_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
    `declare_bsg_wb_widths(paddr_width_p, data_width_p)

    , parameter  boot_pc_p    = 32'h8000_0000
    , parameter  data_width_p = dword_width_gp
  )
  (  input clk_i
   , input reset_i

   // Wishbone ibus
   , output [wb_adr_width_lp-1:0] m00_adr_o
   , output [data_width_p-1:0]    m00_dat_o
   , output                       m00_cyc_o
   , output                       m00_stb_o
   , output [wb_sel_width_lp-1:0] m00_sel_o
   , output                       m00_we_o
   , output [2:0]                 m00_cti_o
   , output [1:0]                 m00_bte_o
   , input                        m00_ack_i
   , input                        m00_err_i
   , input  [data_width_p-1:0]    m00_dat_i

   // Wishbone dbus
   , output [wb_adr_width_lp-1:0] m01_adr_o
   , output [data_width_p-1:0]    m01_dat_o
   , output                       m01_cyc_o
   , output                       m01_stb_o
   , output [wb_sel_width_lp-1:0] m01_sel_o
   , output                       m01_we_o
   , output [2:0]                 m01_cti_o
   , output [1:0]                 m01_bte_o
   , input                        m01_ack_i
   , input                        m01_err_i
   , input  [data_width_p-1:0]    m01_dat_i

   // Wishbone clint
   , input  [wb_adr_width_lp-1:0] c00_adr_i
   , input  [data_width_p-1:0]    c00_dat_i
   , input                        c00_cyc_i
   , input                        c00_stb_i
   , input  [wb_sel_width_lp-1:0] c00_sel_i
   , input                        c00_we_i
   , input  [2:0]                 c00_cti_i
   , input  [1:0]                 c00_bte_i
   , output                       c00_ack_o
   , output                       c00_err_o
   , output [data_width_p-1:0]    c00_dat_o
  );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);


  initial begin
    assert(uce_fill_width_p == dword_width_gp)
      else $error("uce_fill_width_p mmust be equal to dword_width_gp");
  end

  /*
   * unicore_lite
   */
  wire [1:0][mem_fwd_header_width_lp-1:0] proc_mem_fwd_header_lo;
  wire [1:0][uce_fill_width_p-1:0] proc_mem_fwd_data_lo;
  wire [1:0] proc_mem_fwd_v_lo;
  wire [1:0] proc_mem_fwd_ready_and_li;
  wire [1:0] proc_mem_fwd_last_lo;

  wire [1:0][mem_fwd_header_width_lp-1:0] proc_mem_rev_header_li;
  wire [1:0][uce_fill_width_p-1:0] proc_mem_rev_data_li;
  wire [1:0] proc_mem_rev_v_li;
  wire [1:0] proc_mem_rev_ready_and_lo;
  wire [1:0] proc_mem_rev_last_li;

  wire debug_irq_li;
  wire timer_irq_li;
  wire software_irq_li;
  wire m_external_irq_li;
  wire s_external_irq_li;

  bp_cfg_bus_s cfg_bus_lo;
  assign cfg_bus_lo =
  '{freeze       : 1'b0
    ,npc         : boot_pc_p
    ,core_id     : '0
    ,icache_id   : '0
    ,icache_mode : e_lce_mode_normal
    ,dcache_id   : 1'b1
    ,dcache_mode : e_lce_mode_normal
    ,cce_id      : '0
    ,cce_mode    : e_cce_mode_uncached
    ,hio_mask    : '1
  };

  bp_unicore_lite
    #(.bp_params_p(bp_params_p))
    unicore_lite
    ( .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_lo)

     ,.mem_fwd_header_o(proc_mem_fwd_header_lo)
     ,.mem_fwd_data_o(proc_mem_fwd_data_lo)
     ,.mem_fwd_v_o(proc_mem_fwd_v_lo)
     ,.mem_fwd_ready_and_i(proc_mem_fwd_ready_and_li)
     ,.mem_fwd_last_o(proc_mem_fwd_last_lo)

     ,.mem_rev_header_i(proc_mem_rev_header_li)
     ,.mem_rev_data_i(proc_mem_rev_data_li)
     ,.mem_rev_v_i(proc_mem_rev_v_li)
     ,.mem_rev_ready_and_o(proc_mem_rev_ready_and_lo)
     ,.mem_rev_last_i(proc_mem_rev_last_li)

     ,.debug_irq_i(debug_irq_li)
     ,.timer_irq_i(timer_irq_li)
     ,.software_irq_i(software_irq_li)
     ,.m_external_irq_i(m_external_irq_li)
     ,.s_external_irq_i(s_external_irq_li)
    );

  /*
   * unicore_lite I$ -> WB
   */
  bp_me_wb_master
    #(.bp_params_p(bp_params_p)
     ,.data_width_p(data_width_p)
    )
    bp_me_wb_I$
    ( .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(proc_mem_fwd_header_lo[0])
     ,.mem_fwd_data_i(proc_mem_fwd_data_lo[0])
     ,.mem_fwd_v_i(proc_mem_fwd_v_lo[0])
     ,.mem_fwd_ready_and_o(proc_mem_fwd_ready_and_li[0])
     ,.mem_fwd_last_i(proc_mem_fwd_last_lo[0])

     ,.mem_rev_header_o(proc_mem_rev_header_li[0])
     ,.mem_rev_data_o(proc_mem_rev_data_li[0])
     ,.mem_rev_v_o(proc_mem_rev_v_li[0])
     ,.mem_rev_ready_and_i(proc_mem_rev_ready_and_lo[0])
     ,.mem_rev_last_o(proc_mem_rev_last_li[0])

     ,.adr_o(m00_adr_o)
     ,.dat_o(m00_dat_o)
     ,.cyc_o(m00_cyc_o)
     ,.stb_o(m00_stb_o)
     ,.sel_o(m00_sel_o)
     ,.we_o(m00_we_o)
     ,.cti_o(m00_cti_o)
     ,.bte_o(m00_bte_o)

     ,.ack_i(m00_ack_i)
     ,.dat_i(m00_dat_i)
    );

  /*
   * unicore_lite D$ -> WB
   */
  bp_me_wb_master
    #(.bp_params_p(bp_params_p)
     ,.data_width_p(uce_fill_width_p)
    )
    bp_me_wb_D$
    ( .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(proc_mem_fwd_header_lo[1])
     ,.mem_fwd_data_i(proc_mem_fwd_data_lo[1])
     ,.mem_fwd_v_i(proc_mem_fwd_v_lo[1])
     ,.mem_fwd_ready_and_o(proc_mem_fwd_ready_and_li[1])
     ,.mem_fwd_last_i(proc_mem_fwd_last_lo[1])

     ,.mem_rev_header_o(proc_mem_rev_header_li[1])
     ,.mem_rev_data_o(proc_mem_rev_data_li[1])
     ,.mem_rev_v_o(proc_mem_rev_v_li[1])
     ,.mem_rev_ready_and_i(proc_mem_rev_ready_and_lo[1])
     ,.mem_rev_last_o(proc_mem_rev_last_li[1])

     ,.adr_o(m01_adr_o)
     ,.dat_o(m01_dat_o)
     ,.cyc_o(m01_cyc_o)
     ,.stb_o(m01_stb_o)
     ,.sel_o(m01_sel_o)
     ,.we_o(m01_we_o)
     ,.cti_o(m01_cti_o)
     ,.bte_o(m01_bte_o)

     ,.ack_i(m01_ack_i)
     ,.dat_i(m01_dat_i)
    );

  /*
   * clint
   */
  wire [mem_fwd_header_width_lp-1:0] clint_mem_fwd_header_li;
  wire [uce_fill_width_p-1:0] clint_mem_fwd_data_li;
  wire clint_mem_fwd_v_li;
  wire clint_mem_fwd_ready_and_lo;
  wire clint_mem_fwd_last_li;

  wire [mem_fwd_header_width_lp-1:0] clint_mem_rev_header_lo;
  wire [uce_fill_width_p-1:0] clint_mem_rev_data_lo;
  wire clint_mem_rev_v_lo;
  wire clint_mem_rev_ready_and_li;
  wire clint_mem_rev_last_lo;

  bp_me_clint_slice
    #(.bp_params_p(bp_params_p))
    clint
    ( .clk_i(clk_i)
     ,.rt_clk_i(0)
     ,.reset_i(reset_i)
     ,.cfg_bus_i(cfg_bus_lo)

     ,.mem_fwd_header_i(clint_mem_fwd_header_li)
     ,.mem_fwd_data_i(clint_mem_fwd_data_li)
     ,.mem_fwd_v_i(clint_mem_fwd_v_li)
     ,.mem_fwd_ready_and_o(clint_mem_fwd_ready_and_lo)
     ,.mem_fwd_last_i(clint_mem_fwd_last_li)

     ,.mem_rev_header_o(clint_mem_rev_header_lo)
     ,.mem_rev_data_o(clint_mem_rev_data_lo)
     ,.mem_rev_v_o(clint_mem_rev_v_lo)
     ,.mem_rev_ready_and_i(clint_mem_rev_ready_and_li)
     ,.mem_rev_last_o(clint_mem_rev_last_lo)

     ,.debug_irq_o(debug_irq_li)
     ,.timer_irq_o(timer_irq_li)
     ,.software_irq_o(software_irq_li)
     ,.m_external_irq_o(m_external_irq_li)
     ,.s_external_irq_o(s_external_irq_li)
    );

  /*
   * WB -> clint
   */
  assign c00_err_o = '0;
  bp_me_wb_client
    #(.bp_params_p(bp_params_p)
     ,.data_width_p(uce_fill_width_p)
    )
    bp_me_wb_clint
    ( .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i('0)
     ,.did_i('0)

     ,.mem_fwd_header_o(clint_mem_fwd_header_li)
     ,.mem_fwd_data_o(clint_mem_fwd_data_li)
     ,.mem_fwd_v_o(clint_mem_fwd_v_li)
     ,.mem_fwd_ready_and_i(clint_mem_fwd_ready_and_lo)
     ,.mem_fwd_last_o(clint_mem_fwd_last_li)

     ,.mem_rev_header_i(clint_mem_rev_header_lo)
     ,.mem_rev_data_i(clint_mem_rev_data_lo)
     ,.mem_rev_v_i(clint_mem_rev_v_lo)
     ,.mem_rev_ready_and_o(clint_mem_rev_ready_and_li)
     ,.mem_rev_last_i(clint_mem_rev_last_lo)

     ,.adr_i(c00_adr_i)
     ,.dat_i(c00_dat_i)
     ,.cyc_i(c00_cyc_i)
     ,.stb_i(c00_stb_i)
     ,.sel_i(c00_sel_i)
     ,.we_i(c00_we_i)

     ,.ack_o(c00_ack_o)
     ,.dat_o(c00_dat_o)
    );

endmodule
