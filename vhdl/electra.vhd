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
-- @file vnir_subsystem.vhd
-- @author Alexander Epp
-- @date 2020-06-16
----------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.vnir_types.all;
use work.swir_types.all;
use work.ddr3_types.all;
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
        vnir_config     : in vnir_config_t;
        config_done     : out std_logic;
        row_request     : in std_logic;
        is_imaging      : out std_logic;
        row_available   : out std_logic;
        row_1           : out vnir_row_t;
        row_2           : out vnir_row_t;
        row_3           : out vnir_row_t;
        sensor_clock    : out std_logic;
        sensor_reset    : out std_logic;
        spi_clock       : out std_logic;
        spi_miso        : out std_logic;
        spi_ss          : out std_logic;
        spi_mosi        : out std_logic;
        frame_request   : out std_logic;
        lvds_clock      : in std_logic;
        lvds_control     : in std_logic;
        lvds_n, lvds_p  : in unsigned (14 downto 0)
    );
    end component;

    component swir_subsystem
    port (
        clock           : in std_logic;
        reset_n         : in std_logic;
        swir_config     : in swir_config_t;
        config_done     : out std_logic;
        row_request     : in std_logic;
        is_imaging      : out std_logic;
        row_available   : out std_logic;
        row             : out swir_row_t
    );
    end component;

    component ddr3_subsystem
    port (
        clock               : in std_logic;
        reset_n             : in std_logic;
        vnir_row_available  : in std_logic;
        vnir_row_1          : in vnir_row_t;
        vnir_row_2          : in vnir_row_t;
        vnir_row_3          : in vnir_row_t;
        swir_row_available  : in std_logic;
        swir_row            : in swir_row_t;
        timestamp           : in timestamp_t;
        mpu_memory_change   : in std_logic;
        ddr3_config         : in ddr3_config_t;
        ddr3_config_done    : out std_logic;
        ddr3_full           : out std_logic;
        ddr3_busy           : out std_logic;
        write_address       : out std_logic_vector(29 downto 0);
        write_burstcount    : out std_logic_vector(7 downto 0);
        write_waitrequest   : in std_logic;
        write_writedata     : out std_logic_vector(31 downto 0);
        write_byteenable    : out std_logic_vector(3 downto 0);
        write_write         : out std_logic;
        read_address        : out std_logic_vector(29 downto 0);
        read_burstcount     : out std_logic_vector(7 downto 0);
        read_waitrequest    : in std_logic;
        read_readdata       : in std_logic_vector(31 downto 0);
        read_readdatavalid  : in std_logic;
        read_read           : out std_logic
    );
    end component;

    component fpga_subsystem
    port (
        clock               : in std_logic;
        reset_n             : in std_logic;
        row_request         : out std_logic;
        vnir_config         : out vnir_config_t;
        vnir_config_done    : in std_logic;
        vnir_is_imaging     : in std_logic;
        swir_config         : out swir_config_t;
        swir_config_done    : in std_logic;
        swir_is_imaging     : in std_logic;
        timestamp           : out timestamp_t;
        ddr3_config         : out ddr3_config_t;
        ddr3_config_done    : in std_logic;
        request_image       : in std_logic;
        init_timestamp      : in timestamp_t
    );
    end component;

    signal clock    : std_logic;  -- Main clock
    signal reset_n  : std_logic;  -- Main reset

    -- fpga <=> vnir, swir
    signal row_request : std_logic;

    -- fpga <=> vnir
    signal vnir_config : vnir_config_t;
    signal vnir_config_done : std_logic;
    signal vnir_is_imaging : std_logic;

    -- vnir <=> ddr3
    signal vnir_row_available : std_logic;
    signal vnir_row_1 : vnir_row_t;
    signal vnir_row_2 : vnir_row_t;
    signal vnir_row_3 : vnir_row_t;

    -- vnir <=> sensor
    signal vnir_sensor_clock : std_logic;
    signal vnir_sensor_reset : std_logic;
    signal vnir_spi_clock : std_logic;
    signal vnir_spi_miso : std_logic;
    signal vnir_spi_ss : std_logic;
    signal vnir_spi_mosi : std_logic;
    signal vnir_frame_request : std_logic;
    signal vnir_lvds_clock : std_logic;
    signal vnir_lvds_control : std_logic;
    signal vnir_lvds_n : unsigned (14 downto 0);
    signal vnir_lvds_p : unsigned (14 downto 0);

    -- fpga <=> swir
    signal swir_config : swir_config_t;
    signal swir_config_done : std_logic;
    signal swir_is_imaging : std_logic;

    -- swir <=> ddr3
    signal swir_row_available : std_logic;
    signal swir_row : swir_row_t;

    -- fpga <=> ddr3
    signal timestamp : timestamp_t;
    signal ddr3_config : ddr3_config_t;
    signal ddr3_config_done : std_logic;

    -- ddr3 <=> RAM
    signal ddr3_write_address : std_logic_vector(29 downto 0);
    signal ddr3_write_burstcount : std_logic_vector(7 downto 0);
    signal ddr3_write_waitrequest : std_logic;
    signal ddr3_write_writedata : std_logic_vector(31 downto 0);
    signal ddr3_write_byteenable : std_logic_vector(3 downto 0);
    signal ddr3_write_write : std_logic;
    signal ddr3_read_address : std_logic_vector(29 downto 0);
    signal ddr3_read_burstcount : std_logic_vector(7 downto 0);
    signal ddr3_read_waitrequest : std_logic;
    signal ddr3_read_readdata : std_logic_vector(31 downto 0);
    signal ddr3_read_readdatavalid : std_logic;
    signal ddr3_read_read : std_logic;

    -- ddr3 <=> microcontroller
    signal mpu_memory_change : std_logic;
    signal ddr3_full : std_logic;
    signal ddr3_busy : std_logic;

    -- fpga <=> microcontroller
    signal request_image : std_logic;
    signal init_timestamp : timestamp_t;
begin
    soc_system_component : component soc_system port map (
        clk_clk => clock,
        reset_reset_n => reset_n,
        -- TODO: add other stuff here that is autogenerated by QSys
        sdram0_address => ddr3_write_address,
        sdram0_burstcount => ddr3_write_burstcount,
        sdram0_waitrequest => ddr3_write_waitrequest,
        sdram0_writedata => ddr3_write_writedata,
        sdram0_byteenable => ddr3_write_byteenable,
        sdram0_write => ddr3_write_write,
        sdram1_address => ddr3_read_address,
        sdram1_burstcount => ddr3_read_burstcount,
        sdram1_waitrequest => ddr3_read_waitrequest,
        sdram1_readdata => ddr3_read_readdata,
        sdram1_readdatavalid => ddr3_read_readdatavalid,
        sdram1_read => ddr3_read_read
    );

    vnir_subsystem_component : component vnir_subsystem port map (
        clock => clock,
        reset_n => reset_n,
        vnir_config => vnir_config,
        config_done => vnir_config_done,
        row_request => row_request,
        is_imaging => vnir_is_imaging,
        row_available => vnir_row_available,
        row_1 => vnir_row_1,
        row_2 => vnir_row_2,
        row_3 => vnir_row_3,
        sensor_clock => vnir_sensor_clock,
        sensor_reset => vnir_sensor_reset,
        spi_clock => vnir_spi_clock,
        spi_miso => vnir_spi_miso,
        spi_ss => vnir_spi_ss,
        spi_mosi => vnir_spi_mosi,
        frame_request => vnir_frame_request,
        lvds_clock => vnir_lvds_clock,
        lvds_control => vnir_lvds_control,
        lvds_n => vnir_lvds_n,
        lvds_p => vnir_lvds_p
    );

    swir_subsystem_component : component swir_subsystem port map (
        clock => clock,
        reset_n => reset_n,
        swir_config => swir_config,
        config_done => swir_config_done,
        row_request => row_request,
        is_imaging => swir_is_imaging,
        row_available => swir_row_available,
        row => swir_row
    );

    ddr3_subsystem_component : component ddr3_subsystem port map (
        clock => clock,
        reset_n => reset_n,
        vnir_row_available => vnir_row_available,
        vnir_row_1 => vnir_row_1,
        vnir_row_2 => vnir_row_2,
        vnir_row_3 => vnir_row_3,
        swir_row_available => swir_row_available,
        swir_row => swir_row,
        timestamp => timestamp,
        mpu_memory_change => mpu_memory_change,
        ddr3_config => ddr3_config,
        ddr3_config_done => ddr3_config_done,
        ddr3_full => ddr3_full,
        ddr3_busy => ddr3_busy,
        write_address => ddr3_write_address,
        write_burstcount => ddr3_write_burstcount,
        write_waitrequest => ddr3_write_waitrequest,
        write_writedata => ddr3_write_writedata,
        write_byteenable => ddr3_write_byteenable,
        write_write => ddr3_write_write,
        read_address => ddr3_read_address,
        read_burstcount => ddr3_read_burstcount,
        read_waitrequest => ddr3_read_waitrequest,
        read_readdata => ddr3_read_readdata,
        read_readdatavalid => ddr3_read_readdatavalid,
        read_read => ddr3_read_read
    );

    fpga_subsystem_component : component fpga_subsystem port map (
        clock => clock,
        reset_n => reset_n,
        row_request => row_request,
        vnir_config => vnir_config,
        vnir_config_done => vnir_config_done,
        vnir_is_imaging => vnir_is_imaging,
        swir_config => swir_config,
        swir_config_done => swir_config_done,
        swir_is_imaging => swir_is_imaging,
        timestamp => timestamp,
        ddr3_config => ddr3_config,
        ddr3_config_done => ddr3_config_done,
        request_image => request_image,
        init_timestamp => init_timestamp
    );
end;
