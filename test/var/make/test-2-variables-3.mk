VAR3_1 := test/var/make/test-*-*-3.mk
VAR3_2 := $(wildcard $(VAR3_1))
ifneq ($(VAR3_2),$(VAR3_1))
VAR3_3 := $(VAR3_2)
endif
