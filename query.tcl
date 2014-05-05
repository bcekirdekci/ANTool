package provide antool::query 1.0

package require antool

#qlist kitchen:
#list(list,area)
#list(count,area)
#
#find count.(*) - this will be entity types
# call functions
#::antool::query::%ent_type%.operator
#
#q "comp(FIX.N).node.loc(x>0)"
#sel.node.loc(x>0).elem
#
# in future:
#sel.node.+(comp(FIX.N).node)
# all.kp.loc(x=r&z=h&(y=0|y=45),csys=5).line(all=1)+

#current ansys selection is always current qlist  (while query evaluation runs)


## \c antool::query namespace represents command for processing  queries. Every query consists of a source and actions on it
#
namespace eval ::antool::query {
	namespace export *
	set query_hint Q
}




#::antool::query::tokenize "all.elem(type=5).loc(x>5 & y==3,csys=5)"
#regexp {\s*([\w]+)=([^=]+.*)\s*} $str dummy name val
proc ::antool::query::tokenize {query args} {
    set brace_level 0
    set qlen [string length $query]
    set cmds {}
    set _args {}
    set cmdj {}
    set cmdi 0
    set cur_args {}
    for {set i 0} {$i < $qlen} {incr i} {
        set char [string index $query $i]
        if {$char eq "("} {
            incr brace_level
            if {$brace_level == 1} {
                set argi [expr $i+1]
                set cmdj [expr $i-1]
                set cur_args {}
            }
            continue
        } elseif {$char eq ")"} {
            incr brace_level -1
            if {$brace_level == 0} {
                set argj [expr $i-1]
                if {$argj-$argi>-1} {
                    lappend cur_args [string range $query $argi $argj]
                }
            }
        } elseif {$char eq "," && $brace_level == 1} {
            set argj [expr $i-1]
            if {$argj-$argi>0} {
                lappend cur_args [string range $query $argi $argj]
            }
            set argi [expr $i+1]
        }
        if {($char eq "." || $i==$qlen-1) && $brace_level == 0 } {
            if {$cmdj != {}} {
                lappend cmds [string range $query $cmdi $cmdj]
            } else {
                if {$i==$qlen-1} {
                    set cmdj $i
                } else {
                    set cmdj [expr $i-1]
                }
                if {$cmdj-$cmdi>0} {
                    lappend cmds [string range $query $cmdi $cmdj]
                } else {
                    ::antool::utils::error "wtf?"
                }
            }
            set arglist {}
            set ind 1
            foreach ar $cur_args {
                if {[regexp {\s*([\w]+)=([^=]+.*)\s*} $ar dummy name val]} {
                    lappend arglist -$name $val
                } else {
                    lappend arglist -def$ind $ar
                    incr ind
                }
            }
            
            lappend _args $arglist
            lappend cmds $arglist
            set cur_args {}
            set cmdj {}
            set cmdi [expr $i+1]
            continue
        }
    }
    return  $cmds
}

proc ::antool::query::do {args} {
	set list [::antool::utils::unflag	-list	]
	set sel [::antool::utils::unflag	-sel	]
	set qry [join $args " "]
	if {$sel == 0} {
		::antool::comp -push ALKENV
	}
	set cmds [::antool::query::tokenize $qry]
	set len [expr [llength $cmds]/2]
	if {$len < 2} {
		::antool::utils::error "wtf?"
	}
	if {[lindex $cmds 3] != {}} {
		::antool::utils::error "Source dont have two arguments"
	}
	if {[lindex $cmds 1] == {}} {
		eval [concat ::antool::query::sources::[lindex $cmds 0].[lindex $cmds 2] qlist]
	} else {
		eval [concat ::antool::query::sources::[lindex $cmds 0].[lindex $cmds 2] qlist [lindex $cmds 1]]
	}
	foreach {cm ar} [lrange $cmds 4 end] {
		foreach ent [::antool::query::qlist::what_in_list qlist] {
			eval [concat ::antool::query::$ent.$cm qlist $ar]
		}
		
	}
	if {$sel == 0} {
		::antool::comp -pop
	}
	if {$list} {
		set cmd ::antool::list::build
		foreach ent [::antool::query::qlist::what_in_list qlist] {
			lappend cmd -$ent $qlist(list,$ent)
		}
		return [eval $cmd]
	}
}

## \c antool::query::qlist is a namespace for functions working with qlists. qlist is a complex list where objects sets is saved.
namespace eval ::antool::query::qlist {
    set entity_types {1 node 2 elem 3 kp 4 line 5 area 6 volu}
    
    proc init {_qlist} {
        upvar $_qlist qlist
        variable entity_types
        array set qlist {}
		array unset qlist
        foreach {n e} $entity_types {
            set qlist(list,$e) {}
            set qlist(count,$e) 0
        }
    }
    
    proc qlist_selection {_qlist args} {
		upvar $_qlist qlist
		set type [::antool::utils::unarg	-type	{}	]
		foreach t $type {
			set qlist(list,$t) [::antool::list_selection -$t]
			set qlist(count,$t) [llength $qlist(list,$t)]
		}
    }
	
	proc qilst_to_selection {_qlist} {
		
	}
	
	proc what_in_list {_qlist args} {
		upvar $_qlist qlist
		set ents {}
		foreach name [array names qlist -glob "count,*"] {
			if {$qlist($name) > 0} {
				if {[regexp {\s*count,(.*)\s*} $name dummy ent]}  {
					lappend ents $ent
				} else {
					::antool::utils::error "Can't regexp $name"
				}
			}
		}
		return $ents
	}
}

## \c antool::query::sources is a namespace to store all query sources in one place. Query sources is a initial initial qlist on which next commands will work.
namespace eval ::antool::query::sources {

    proc sel.node {_qlist args} {
        upvar $_qlist qlist
        antool::query::qlist::init qlist
        antool::query::qlist::qlist_selection qlist -type node
		#unselect all others
		::antool::sel -elem -none
		::antool::sel -area -none
		::antool::sel -volu -none
		::antool::sel -kps -none
		::antool::sel -line -none
    }
	proc sel.elem {_qlist args} {
        upvar $_qlist qlist
        antool::query::qlist::init qlist
        antool::query::qlist::qlist_selection qlist -type elem
		#unselect all others
		::antool::sel -node -none
		::antool::sel -area -none
		::antool::sel -volu -none
		::antool::sel -kps -none
		::antool::sel -line -none
    }
	proc sel.kp {_qlist args} {
        upvar $_qlist qlist
        antool::query::qlist::init qlist
        antool::query::qlist::qlist_selection qlist -type kp
		#unselect all others
		::antool::sel -node -none
		::antool::sel -area -none
		::antool::sel -volu -none
		::antool::sel -elem -none
		::antool::sel -line -none
    }
	proc sel.line {_qlist args} {
        upvar $_qlist qlist
        antool::query::qlist::init qlist
        antool::query::qlist::qlist_selection qlist -type line
		#unselect all others
		::antool::sel -node -none
		::antool::sel -area -none
		::antool::sel -volu -none
		::antool::sel -elem -none
		::antool::sel -kp -none
    }
	proc sel.area {_qlist args} {
        upvar $_qlist qlist
        antool::query::qlist::init qlist
        antool::query::qlist::qlist_selection qlist -type area
		#unselect all others
		::antool::sel -node -none
		::antool::sel -line -none
		::antool::sel -volu -none
		::antool::sel -elem -none
		::antool::sel -kp -none
    }
	proc sel.volu {_qlist args} {
        upvar $_qlist qlist
        antool::query::qlist::init qlist
        antool::query::qlist::qlist_selection qlist -type volu
		#unselect all others
		::antool::sel -node -none
		::antool::sel -line -none
		::antool::sel -area -none
		::antool::sel -elem -none
		::antool::sel -kp -none
    }
	
	
	proc all.node {_qlist args} {
        upvar $_qlist qlist
        ::antool::query::qlist::init qlist
		::antool::sel -node -all
        ::antool::query::qlist::qlist_selection qlist -type node
		#unselect all others
		::antool::sel -elem -none
		::antool::sel -area -none
		::antool::sel -volu -none
		::antool::sel -kps -none
		::antool::sel -line -none
    }
	proc all.elem {_qlist args} {
        upvar $_qlist qlist
        ::antool::query::qlist::init qlist
		::antool::sel -elem -all
        ::antool::query::qlist::qlist_selection qlist -type elem
		#unselect all others
		::antool::sel -line -none
		::antool::sel -area -none
		::antool::sel -volu -none
		::antool::sel -kps -none
		::antool::sel -node -none
    }
	proc all.kp {_qlist args} {
        upvar $_qlist qlist
        ::antool::query::qlist::init qlist
		::antool::sel -kp -all
        ::antool::query::qlist::qlist_selection qlist -type kp
		#unselect all others
		::antool::sel -elem -none
		::antool::sel -area -none
		::antool::sel -volu -none
		::antool::sel -line -none
		::antool::sel -node -none
    }
	proc all.line {_qlist args} {
        upvar $_qlist qlist
        ::antool::query::qlist::init qlist
		::antool::sel -line -all
        ::antool::query::qlist::qlist_selection qlist -type line
		#unselect all others
		::antool::sel -elem -none
		::antool::sel -area -none
		::antool::sel -volu -none
		::antool::sel -kps -none
		::antool::sel -node -none
    }
	proc all.area {_qlist args} {
        upvar $_qlist qlist
        ::antool::query::qlist::init qlist
		::antool::sel -area -all
        ::antool::query::qlist::qlist_selection qlist -type area
		#unselect all others
		::antool::sel -elem -none
		::antool::sel -line -none
		::antool::sel -volu -none
		::antool::sel -kps -none
		::antool::sel -node -none
    }
	proc all.volu {_qlist args} {
        upvar $_qlist qlist
        ::antool::query::qlist::init qlist
		::antool::sel -volu -all
        ::antool::query::qlist::qlist_selection qlist -type volu
		#unselect all others
		::antool::sel -elem -none
		::antool::sel -line -none
		::antool::sel -area -none
		::antool::sel -kps -none
		::antool::sel -node -none
    }
	
	#warning if there is no nodes in comp
	proc comp.node {_qlist args} {
		set comp   [::antool::utils::unarg     -def1   {}  ]
        upvar $_qlist qlist
		if {$comp == {}} {
			::antool::utils::error "Need the comp name"
		}
        ::antool::query::qlist::init qlist
		::antool::sel -node -none
		::antool::asel -comp $comp
        ::antool::query::qlist::qlist_selection qlist -type node
		::antool::sel -elem -none
		::antool::sel -area -none
		::antool::sel -volu -none
		::antool::sel -kps -none
		::antool::sel -line -none
    }
	
	proc comp.elem {_qlist args} {
		set comp   [::antool::utils::unarg     -def1   {}  ]
        upvar $_qlist qlist
		if {$comp == {}} {
			::antool::utils::error "Need the comp name"
		}
        ::antool::query::qlist::init qlist
		::antool::sel -elem -none
		::antool::asel -comp $comp
        ::antool::query::qlist::qlist_selection qlist -type elem
		::antool::sel -node -none
		::antool::sel -area -none
		::antool::sel -volu -none
		::antool::sel -kps -none
		::antool::sel -line -none
    }
	
	proc comp.kp {_qlist args} {
		set comp   [::antool::utils::unarg     -def1   {}  ]
        upvar $_qlist qlist
		if {$comp == {}} {
			::antool::utils::error "Need the comp name"
		}
        ::antool::query::qlist::init qlist
		::antool::sel -kp -none
		::antool::asel -comp $comp
        ::antool::query::qlist::qlist_selection qlist -type kp
		::antool::sel -node -none
		::antool::sel -area -none
		::antool::sel -volu -none
		::antool::sel -elem -none
		::antool::sel -line -none
    }
	
	proc comp.line {_qlist args} {
		set comp   [::antool::utils::unarg     -def1   {}  ]
        upvar $_qlist qlist
		if {$comp == {}} {
			::antool::utils::error "Need the comp name"
		}
        ::antool::query::qlist::init qlist
		::antool::sel -line -none
		::antool::asel -comp $comp
        ::antool::query::qlist::qlist_selection qlist -type line
		::antool::sel -node -none
		::antool::sel -area -none
		::antool::sel -volu -none
		::antool::sel -elem -none
		::antool::sel -kp -none
    }
	
	proc comp.area {_qlist args} {
		set comp   [::antool::utils::unarg     -def1   {}  ]
        upvar $_qlist qlist
		if {$comp == {}} {
			::antool::utils::error "Need the comp name"
		}
        ::antool::query::qlist::init qlist
		::antool::sel -area -none
		::antool::asel -comp $comp
        ::antool::query::qlist::qlist_selection qlist -type area
		::antool::sel -node -none
		::antool::sel -line -none
		::antool::sel -volu -none
		::antool::sel -elem -none
		::antool::sel -kp -none
    }
	
	proc comp.volu {_qlist args} {
		set comp   [::antool::utils::unarg     -def1   {}  ]
        upvar $_qlist qlist
		if {$comp == {}} {
			::antool::utils::error "Need the comp name"
		}
        ::antool::query::qlist::init qlist
		::antool::sel -volu -none
		::antool::asel -comp $comp
        ::antool::query::qlist::qlist_selection qlist -type volu
		::antool::sel -node -none
		::antool::sel -line -none
		::antool::sel -area -none
		::antool::sel -elem -none
		::antool::sel -kp -none
    }
	
	proc list.node {_qlist args} {
		set list   [::antool::utils::unarg     -def1   {}  ]
        upvar $_qlist qlist
		set t node
		set list [::antool::list::only -list $list -type $t]
		::antool::sel -nonesel
		::antool::sel -q $list
        ::antool::query::qlist::init qlist
		set qlist(list,$t) [::antool::list::enumerate -list $list -type $t]
		set qlist(count,$t) [llength $qlist(list,$t)]
	}
	
	proc list.elem {_qlist args} {
		set list   [::antool::utils::unarg     -def1   {}  ]
        upvar $_qlist qlist
		set t elem
		set list [::antool::list::only -list $list -type $t]
		::antool::sel -nonesel
		::antool::sel -q $list
        ::antool::query::qlist::init qlist
		set qlist(list,$t) [::antool::list::enumerate -list $list -type $t]
		set qlist(count,$t) [llength $qlist(list,$t)]
	}
	
	proc list.kp {_qlist args} {
		set list   [::antool::utils::unarg     -def1   {}  ]
        upvar $_qlist qlist
		set t kp
		set list [::antool::list::only -list $list -type $t]
		::antool::sel -nonesel
		::antool::sel -q $list
        ::antool::query::qlist::init qlist
		set qlist(list,$t) [::antool::list::enumerate -list $list -type $t]
		set qlist(count,$t) [llength $qlist(list,$t)]
	}
	
	proc list.line {_qlist args} {
		set list   [::antool::utils::unarg     -def1   {}  ]
        upvar $_qlist qlist
		set t line
		set list [::antool::list::only -list $list -type $t]
		::antool::sel -nonesel
		::antool::sel -q $list
        ::antool::query::qlist::init qlist
		set qlist(list,$t) [::antool::list::enumerate -list $list -type $t]
		set qlist(count,$t) [llength $qlist(list,$t)]
	}
	
	proc list.area {_qlist args} {
		set list   [::antool::utils::unarg     -def1   {}  ]
        upvar $_qlist qlist
		set t area
		set list [::antool::list::only -list $list -type $t]
		::antool::sel -nonesel
		::antool::sel -q $list
        ::antool::query::qlist::init qlist
		set qlist(list,$t) [::antool::list::enumerate -list $list -type $t]
		set qlist(count,$t) [llength $qlist(list,$t)]
	}
	
	proc list.volu {_qlist args} {
		set list   [::antool::utils::unarg     -def1   {}  ]
        upvar $_qlist qlist
		set t volu
		set list [::antool::list::only -list $list -type $t]
		::antool::sel -nonesel
		::antool::sel -q $list
        ::antool::query::qlist::init qlist
		set qlist(list,$t) [::antool::list::enumerate -list $list -type $t]
		set qlist(count,$t) [llength $qlist(list,$t)]
	}
}





proc ::antool::query::node.loc {_qlist args} {
    set coord   [::antool::utils::unarg     -def1   "none"  ]
    upvar $_qlist qlist
    rsel -node -coord $coord
    ::antool::query::qlist::qlist_selection qlist -type node
    return 1
    #1 - update qlist as selection
    #2 - update selection as qlist
    #3 - do nothing
}

proc ::antool::query::node.elem {_qlist args} {
    set all   [::antool::utils::unarg     -def1   {}  ]
    upvar $_qlist qlist
	if {$all eq "all"} {
		set all 1
	} else {
		set all 0
	}
	apdl "ESLN,S,$all"
	::antool::query::qlist::init qlist
    ::antool::query::qlist::qlist_selection qlist -type elem
	::antool::sel -node -none
    return 1
    #1 - update qlist as selection
    #2 - update selection as qlist
    #3 - do nothing
}



proc ::antool::query::kp.loc {_qlist args} {
    set coord   [::antool::utils::unarg     -def1   "none"  ]
    upvar $_qlist qlist
    rsel -kp -coord $coord
    ::antool::query::qlist::qlist_selection qlist -type kp
    return 1
    #1 - update qlist as selection
    #2 - update selection as qlist
    #3 - do nothing
}



proc ::antool::query::kp.node {_qlist args} {
#    set all     [::antool::utils::unarg     -def1       "no"    ]
#    set from    [::antool::utils::unarg     -from       "all"   ]
    upvar $_qlist qlist
    ::antool::apdl "NSLK, S"
	::antool::sel -kp -none
	::antool::query::qlist::init qlist
    ::antool::query::qlist::qlist_selection qlist -type node
    return 1
}

proc ::antool::query::kp.line {_qlist args} {
	set all   [::antool::utils::unarg     -def1   {}  ]
    upvar $_qlist qlist
	if {$all eq "all"} {
		set all 1
	} else {
		set all 0
	}
	::antool::apdl "LSLK,S,$all"
	::antool::sel -kp -none
	::antool::query::qlist::init qlist
    ::antool::query::qlist::qlist_selection qlist -type line
    return 1
}

#TODO: not work now
proc ::antool::query::kp.sort {_qlist args} {
    set dir     [::antool::utils::unarg     -def1       "none"  ]
    set order     [::antool::utils::unarg     -order       "desc"  ]
    upvar $_qlist qlist
    set dirlist [] ; #TODO: list with $dir porperty of entityies
    #TODO: sort it by $order
    return 1
}

proc ::antool::query::volu.area {_qlist args} {
    upvar $_qlist qlist
	apdl "ASLV,S"
	::antool::query::qlist::init qlist
    ::antool::query::qlist::qlist_selection qlist -type area
	::antool::sel -volu -none
    return 1
}

proc ::antool::query::volu.elem {_qlist args} {
    upvar $_qlist qlist
	apdl "ESLV,S"
	::antool::query::qlist::init qlist
    ::antool::query::qlist::qlist_selection qlist -type elem
	::antool::sel -volu -none
    return 1
}

proc ::antool::query::area.node {_qlist args} {
	set int     [::antool::utils::unarg     -def1  	{}]
	if {$int eq "int"} {
		set int 0
	} else {
		set int 1
		apdl "LSLA,S"
	}
    upvar $_qlist qlist
	apdl "NSLA,S,$int"
	::antool::query::qlist::init qlist
    ::antool::query::qlist::qlist_selection qlist -type node
	::antool::sel -area -none
	::antool::sel -line -none
    return 1
}

proc ::antool::query::line.dir {_qlist args} {
	set coord     [::antool::utils::unarg     -def1  	{}]
    upvar $_qlist qlist
	::antool::select -lines -angle $coord
	::antool::query::qlist::init qlist
    ::antool::query::qlist::qlist_selection qlist -type line
    return 1
}

proc ::antool::query::volu.line {_qlist args} {
    upvar $_qlist qlist
	apdl "ASLV,S"
	apdl "LSLA,S"
	::antool::query::qlist::init qlist
    ::antool::query::qlist::qlist_selection qlist -type line
	::antool::sel -volu -none
	::antool::sel -area -none
    return 1
}

proc ::antool::query::elem.type {_qlist args} {
	set type     [::antool::utils::unarg     -def1  	{}]
    upvar $_qlist qlist
	if {$type == {}} {
		::antool::utils::error "no type number was provided"
	}
	if {[llength $type] == 1} {
		apdl "ESEL,R,TYPE,,$type  "
	} else {
		set ind 1
		set cmp [comp -elem -temp]
		foreach t $type {
			if {$ind == 1} {
				apdl "ESEL,R,TYPE,,$t  "
				set cmp2 [comp -elem -temp]
			} else {
				sel -comp $cmp
				apdl "ESEL,R,TYPE,,$t  "
				comp -add -elem -name $cmp2
			}
			incr ind
		}
		sel -comp $cmp2
	}
	::antool::query::qlist::init qlist
    ::antool::query::qlist::qlist_selection qlist -type elem
    return 1
}

proc ::antool::query::elem.real {_qlist args} {
	set real     [::antool::utils::unarg     -def1  	{}]
    upvar $_qlist qlist
	if {$real == {}} {
		::antool::utils::error "no type number was provided"
	}
	if {[llength $real] == 1} {
		apdl "ESEL,R,REAL,,$real  "
	} else {
		set ind 1
		set cmp [comp -elem -temp]
		foreach t $real {
			if {$ind == 1} {
				apdl "ESEL,R,REAL,,$t  "
				set cmp2 [comp -elem -temp]
			} else {
				sel -comp $cmp
				apdl "ESEL,R,REAL,,$t  "
				comp -add -elem -name $cmp2
			}
			incr ind
		}
		sel -comp $cmp2
	}
	::antool::query::qlist::init qlist
    ::antool::query::qlist::qlist_selection qlist -type elem
    return 1
}
