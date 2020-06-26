----------------------------------------------------------------
--	
--	 Copyright (C) 2015  University of Alberta
--	
--	 This program is free software; you can redistribute it and/or
--	 modify it under the terms of the GNU General Public License
--	 as published by the Free Software Foundation; either version 2
--	 of the License, or (at your option) any later version.
--	
--	 This program is distributed in the hope that it will be useful,
--	 but WITHOUT ANY WARRANTY; without even the implied warranty of
--	 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--	 GNU General Public License for more details.
--	
--	
-- @file electra.vhd
-- @author Alexander Epp
-- @date 2020-06-16
----------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.spi_types.all;
use work.avalonmm_types.all;
use work.vnir_types.all;
use work.swir_types.all;
use work.sdram_types.all;
use work.fpga_types.all;

entity electra is
    -- port (
        -- FPGA pins go here
    -- );
end electra;


architecture rtl of electra is
    component soc_system
    port (
        clk_clk                         : in    std_logic;
        reset_reset_n                   : in    std_logic;
        -- TODO: add otherstuff here that is autogenerated by QSys
        sdram0_address                  : in    std_logic_vector(29 downto 0);
        sdram0_burstcount               : in    std_logic_vector(7 downto 0);
        sdram0_waitrequest              : out   std_logic;
        sdram0_writedata                : in    std_logic_vector(31 downto 0);
        sdram0_byteenable               : in    std_logic_vector(3 downto 0);
        sdram0_write                    : in    std_logic;
        sdram1_address                  : in    std_logic_vector(29 downto 0);
        sdram1_burstcount               : in    std_logic_vector(7 downto 0);
        sdram1_waitrequest              : out   std_logic;
        sdram1_readdata                 : out   std_logic_vector(31 downto 0);
        sdram1_readdatavalid            : out   std_logic;
        sdram1_read                     : in    std_logic
    );
    end component;

    component vnir_subsystem
    port (
        clock           : in std_logic;
        reset_n         : in std_logic;
        config          : in vnir_config_t;
        config_done     : out std_logic;
        do_imaging      : in std_logic;
        num_rows        : out integer;
        rows            : out vnir_rows_t;
        rows_available  : out std_logic;
        sensor_clock    : out std_logic;
        sensor_reset    : out std_logic;
        spi_out         : out spi_from_master_t;
        spi_in          : in spi_to_master_t;
        frame_request   : out std_logic;
        lvds            : in vnir_lvds_t
    );
    end component;

    component swir_subsystem
    port (
        clock           : in std_logic;
        reset_n         : in std_logic;
        config          : in swir_config_t;
        control         : out swir_control_t;
        config_done     : out std_logic;
        do_imaging      : in std_logic;
        num_rows        : out integer;
        row             : out swir_row_t;
        row_available   : out std_logic;
        sensor_clock    : out std_logic;
        sensor_reset    : out std_logic
    );
    end component;

    component sdram_subsystem
    port (
        clock               : in std_logic;
        reset_n             : in std_logic;
        vnir_rows_available : in std_logic;
        num_vnir_rows       : in integer;
        vnir_rows           : in vnir_rows_t;
        swir_row_available  : in std_logic;
        num_swir_rows       : in integer;
        swir_row            : in swir_row_t;
        timestamp           : in timestamp_t;
        mpu_memory_change   : in std_logic;
        sdram_config         : in sdram_config_t;
        sdram_config_done    : out std_logic;
        sdram_busy           : out std_logic;
        sdram_error          : out std_logic;
        sdram_full           : out std_logic;
        sdram_avalon_out     : out avalonmm_rw_from_master_t;
        sdram_avalon_in      : in avalonmm_rw_to_master_t
    );
    end component;

    component fpga_subsystem
    port (
        clock               : in std_logic;
        reset_n             : in std_logic;
        vnir_config         : out vnir_config_t;
        vnir_config_done    : in std_logic;
        swir_config         : out swir_config_t;
        swir_config_done    : in std_logic;
        sdram_config         : out sdram_config_t;
        sdram_config_done    : in std_logic;
        num_vnir_rows       : in integer;
        num_swir_rows       : in integer;
        do_imaging          : out std_logic;
        timestamp           : out timestamp_t;
        init_timestamp      : in timestamp_t;
        image_request       : in std_logic;
        imaging_duration    : in integer
    );
    end component;

    signal clock    : std_logic;  -- Main clock
    signal reset_n  : std_logic;  -- Main reset

    -- fpga <=> vnir, swir
    signal do_imaging : std_logic;

    -- fpga <=> vnir
    signal vnir_config : vnir_config_t;
    signal vnir_config_done : std_logic;
    
    -- vnir <=> sdram
    signal vnir_rows : vnir_rows_t;
    signal vnir_rows_available : std_logic;
    
    -- vnir <=> sensor
    signal vnir_sensor_clock : std_logic;
    signal vnir_sensor_reset : std_logic;
    signal vnir_spi : spi_t;
    signal vnir_frame_request : std_logic;
    signal vnir_lvds : vnir_lvds_t;

    -- vnir <=> sdram, fpga
    signal num_vnir_rows;

    -- swir <=> sdram, fpga
    signal num_swir_rows;

    -- fpga <=> swir
    signal swir_config : swir_config_t;
    signal swir_config_done : std_logic;

    -- swir <=> sdram
    signal swir_row : swir_row_t;
    signal swir_row_available : std_logic;

    -- swir <=> sensor
    signal swir_sensor_clock : std_logic;
    signal swir_sensor_reset : std_logic;
    signal swir_control      : swir_control_t;

    -- fpga <=> sdram
    signal timestamp : timestamp_t;
    signal mpu_memory_change : std_logic;
    signal sdram_config : sdram_config_t;
    signal sdram_config_done : std_logic;
    signal sdram_busy : std_logic;
    signal sdram_error : std_logic;
    signal sdram_full : std_logic;

    -- sdram <=> RAM
    signal sdram_avalon : avalonmm_rw_t;

    -- fpga <=> microcontroller
    signal init_timestamp : timestamp_t;
    signal image_request : std_logic;
    signal imaging_duration : integer;
    -- TODO: add on to this

begin
    soc_system_component : soc_system port map (
        clk_clk => clock,
        reset_reset_n => reset_n,
        -- TODO: add other stuff here that is autogenerated by QSys
        sdram0_address => sdram_avalon.from_master.w.address,
        sdram0_burstcount => sdram_avalon.from_master.w.burst_count,
        sdram0_waitrequest => sdram_avalon.to_master.w.wait_request,
        sdram0_writedata => sdram_avalon.from_master.w.write_data,
        sdram0_byteenable => sdram_avalon.from_master.w.byte_enable,
        sdram0_write => sdram_avalon.from_master.w.write_cmd,
        sdram1_address => sdram_avalon.from_master.r.address,
        sdram1_burstcount => sdram_avalon.from_master.r.burst_count,
        sdram1_waitrequest => sdram_avalon.to_master.r.wait_request,
        sdram1_readdata => sdram_avalon.to_master.r.read_data,
        sdram1_readdatavalid => sdram_avalon.to_master.r.read_data_valid,
        sdram1_read => sdram_avalon.from_master.r.read_cmd
    );

    vnir_subsystem_component : vnir_subsystem port map (
        clock => clock,
        reset_n => reset_n,
        config => vnir_config,
        config_done => vnir_config_done,
        do_imaging => do_imaging,
        num_rows => num_vnir_rows,
        rows => vnir_rows,
        rows_available => vnir_rows_available,
        sensor_clock => vnir_sensor_clock,
        sensor_reset => vnir_sensor_reset,
        spi_out => vnir_spi.from_master,
        spi_in => vnir_spi.to_master,
        frame_request => vnir_frame_request,
        lvds => vnir_lvds
    );

    swir_subsystem_component : swir_subsystem port map (
        clock => clock,
        reset_n => reset_n,
        config => swir_config,
        control => swir_control,
        config_done => swir_config_done,
        do_imaging => do_imaging,
        num_rows => num_swir_rows,
        row => swir_row,
        row_available => swir_row_available,
        sensor_clock => swir_sensor_clock,
        sensor_reset => swir_sensor_reset
    );

    sdram_subsystem_component : sdram_subsystem port map (
        clock => clock,
        reset_n => reset_n,
        vnir_rows_available => vnir_rows_available,
        num_vnir_rows => num_vnir_rows,
        vnir_rows => vnir_rows,
        swir_row_available => swir_row_available,
        num_swir_rows => num_swir_rows,
        swir_row => swir_row,
        timestamp => timestamp,
        mpu_memory_change => mpu_memory_change,
        sdram_config => sdram_config,
        sdram_config_done => sdram_config_done,
        sdram_busy => sdram_busy,
        sdram_error => sdram_error,
        sdram_full => sdram_full,
        sdram_avalon_out => sdram_avalon.from_master,
        sdram_avalon_in => sdram_avalon.to_master
    );

    fpga_subsystem_component : fpga_subsystem port map (
        clock => clock,
        reset_n => reset_n,
        vnir_config => vnir_config,
        vnir_config_done => vnir_config_done,
        swir_config => swir_config,
        swir_config_done => swir_config_done,
        sdram_config => sdram_config,
        sdram_config_done => sdram_config_done,
        num_vnir_rows => num_vnir_rows,
        num_swir_rows => num_swir_rows,
        do_imaging => do_imaging,
        timestamp => timestamp,
        init_timestamp => init_timestamp,
        image_request => image_request,
        imaging_duration => imaging_duration
    );
end;
