# Copyright 2018 Tomas Brabec
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SHELL=bash

vsrc = wrap.sv $(wildcard ../../src/*.sv)
vtop = wrap
csrc = VerilatorScTracer.cpp tb_wrap.cpp sc_main.cpp
cflags =
objdir = obj
obj = sim
vflags = -CFLAGS "-I.. -I$(SYSTEMC_INCLUDE)$(if $(cflags), $(cflags))" -LDFLAGS "-L $(SYSTEMC_LIBDIR)" --sc --exe --Mdir $(objdir) \
	 --trace --top-module $(vtop)
vflags_extra =
sflags =


.PHONY: all build
all build: $(objdir)/$(obj)

.PHONY: verilate
verilate: $(objdir)/V$(vtop).mk

$(objdir)/V$(vtop).mk: $(vsrc)
	verilator $(vflags) $(vflags_extra) -o $(notdir $(obj)) $(csrc) $(vsrc)

$(objdir)/$(obj): $(objdir)/V$(vtop).mk $(csrc)
	make -C $(objdir) -f V$(vtop).mk

.PHONY: clean
clean:
	rm -rf $(objdir)

