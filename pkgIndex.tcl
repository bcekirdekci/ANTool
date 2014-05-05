#package ifneeded ADDMIDNODES 1.0 "source [file join $dir add_mid_nodes.tcl]"
#package ifneeded READFRONT 1.0 "source [file join $dir read_front.tcl]"
package ifneeded PATRANKILA 1.0 "set ::PATRANKILA 1; source [file join $dir partankila.tcl]; package provide PATRANKILA 1.0"

package ifneeded PATRANKILA_nv 1.0 "set ::PATRANKILA 1; source [file join $dir nv patrankila.tcl]; package provide PATRANKILA_nv 1.0"
package ifneeded PATRANKILA_mod1 1.0 "source [file join $dir nv mod1.tcl]; package provide PATRANKILA_mod1 1.0"

package ifneeded antool 0.1 "source \"[file join $dir antool.tcl]\""
package ifneeded antool::utils 1.0 "source \"[file join $dir utils.tcl]\""
package ifneeded antool::query 1.0 "source \"[file join $dir query.tcl]\""
package ifneeded antool::list 1.0 "source \"[file join $dir list.tcl]\""


