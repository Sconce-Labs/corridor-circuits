DIR = corridor_eligibility

.PHONY: check test execute fmt info
check:   ; cd $(DIR) && nargo check
test:    ; cd $(DIR) && nargo test
execute: ; cd $(DIR) && nargo execute
fmt:     ; cd $(DIR) && nargo fmt
info:    ; cd $(DIR) && nargo info
