// Contains common parameter definitions for the QSTU subsystem.

`ifndef QSTU_DEFS_VH
`define QSTU_DEFS_VH

// Data widths for sensor and status inputs
`define HEALTH_PARAM_WIDTH   8
`define TEMP_WIDTH          12

// Data widths for configuration parameters
`define WEIGHT_WIDTH        16
`define THRESHOLD_WIDTH     16
`define TEMP_LIMIT_WIDTH    13

// Internal calculation precision
`define SCORE_WIDTH         16
`define MULT_WIDTH          32
`define ACCUM_WIDTH         32

`endif // QSTU_DEFS_VH