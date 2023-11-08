export DESIGN_NAME = gcd
export PLATFORM    = nangate45

export VERILOG_FILES = ./designs/src/$(DESIGN_NAME)/gcd.v 

export SDC_FILE = ./designs/$(PLATFORM)/$(DESIGN_NAME)/constraint.sdc
export ABC_AREA = 1

export CORE_UTILIZATION ?= 50
export PLACE_DENSITY_LB_ADDON = 0.30
