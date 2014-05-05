package provide antool::list 1.0

package require antool::utils


namespace eval ::antool::list {
	namespace export *
	set types_list {node N elem E kp K line L area A volu V}	;# main list of entity types
	array set types_short_to_long {}	;# auto fill in _init
	array set types_long_to_short {}	;# auto fill in _init
	set types_shortlist {}				;# auto fill in _init
	set list_hint L
}

proc ::antool::list::_init {} {
	variable types_list
	variable types_short_to_long
	variable types_long_to_short
	variable types_shortlist
	
	array 	set types_short_to_long	{}
	array 	set types_long_to_short		{}
	set 	types_shortlist 		{}
	
	foreach {long short} $types_list {
		set types_short_to_long($short) $long
		set types_long_to_short($long) $short
		lappend types_shortlist $short
	}
	
}

proc ::antool::list::build {args} {
		::antool::utils::unarg2		arg		node	-nod*	{}
		::antool::utils::unarg2		arg		elem	-ele*	{}
		::antool::utils::unarg2		arg		kp		-kp*	{}
		::antool::utils::unarg2		arg		line	-lin*	{}
		::antool::utils::unarg2		arg		area	-ar*	{}
		::antool::utils::unarg2		arg		volu	-vol*	{}
		::antool::utils::isargs

		variable types_list
		set list ""
		foreach {var code} $types_list {
			if {[set $var] != {}} {
				append list "$code [::antool::list::roll_list [set $var]] "
			}
		}
		return $list
}

proc ::antool::list::selection {args} {
	::antool::utils::unarg2	arg	type -type
	::antool::utils::isargs
	variable types_short_to_long
	
	set cmd "::antool::list::build "
	foreach sh [split $type ""] {
		set list {}
		set nl [ans_getvalue "$types_short_to_long($sh),0,COUNT"]
		if {$nl != 0} {
			set cn 0
			for {set i 0} {$i < $nl} {incr i} {
				set cn [ans_getvalue "$types_short_to_long($sh),$cn,NXTH"]
				lappend list $cn
			}
		}
		if {$list != {}} {
			lappend cmd -$types_short_to_long($sh) $list
		}
	}
	return [eval $cmd]
}

proc ::antool::list::enumerate {args} {
	::antool::utils::unarg2		arg		list 	-li*
	::antool::utils::unarg2		arg		type 	-ty*
	::antool::utils::isargs
	variable types_shortlist
	variable types_long_to_short

	set intype 0
	set typelist {}
	set ll [llength $list]
	for {set i 0} {$i < $ll} {incr i} {
		if {[string match \[[join $types_shortlist]\] [lindex $list $i]]} {
			if {[lindex $list $i] eq $types_long_to_short([string tolower $type])} {
				set intype 1
			} else {
				set intype 0
			}
			continue
		}
		if {$intype} {
			lappend typelist [lindex $list $i]
		}
	}
	return [::antool::list::unroll_list $typelist]
}

proc ::antool::list::only {args} {
	::antool::utils::unarg2		arg		list 	-li*
	::antool::utils::unarg2		arg		type 	-ty*
	::antool::utils::isargs
	variable types_shortlist
	variable types_long_to_short

	set intype 0
	set typelist {}
	set ll [llength $list]
	for {set i 0} {$i < $ll} {incr i} {
		if {[string match \[[join $types_shortlist]\] [lindex $list $i]]} {
			if {[lindex $list $i] eq $types_long_to_short([string tolower $type])} {
				set intype 1
			} else {
				set intype 0
			}
			continue
		}
		if {$intype} {
			lappend typelist [lindex $list $i]
		}
	}
	return "$types_long_to_short([string tolower $type]) $typelist"
}

proc ::antool::list::unroll_list {list} {
	set ol {}
	set tokens [split [string map {, " "} $list] " "]
	foreach tok $tokens {
		if {[regexp {^\s*(\d+)(:|)(\d+|)\s*$} $tok dummy n1 d n2]} {
			if {$n2 == ""} {
				lappend ol $n1
			} else {
				if {$n2 < $n1} {
					set p $n2
					set n2 $n1
					set n1 $n2
				}
				for {set i $n1} {$i <= $n2} {incr i} {
					lappend ol $i	
				}
			}
		} else {
			 ::antool::utils::error  "Can't parse list $tok"
		}
	}
	return $ol
}

proc ::antool::list::roll_list {list} {
	set tokens [split [string map {, " "} $list] " "]
	set lt [llength $tokens]
	set ri {}
	set rj {}
	set output {}
	for {set i 0} {$i < [expr $lt-1]} {incr i} {
		if { $ri == {} } {
			if {[lindex $tokens [expr $i+1]]-[lindex $tokens $i] == 1} {
				set ri $i
				continue
			} else {
				lappend output [lindex $tokens $i]
			}
		} else {
			if {[lindex $tokens [expr $i+1]]-[lindex $tokens $i] == 1} {
				continue
			} else {
				if {[lindex $tokens $i]-[lindex $tokens $ri] > 1} {
					lappend output [lindex $tokens $ri]:[lindex $tokens $i]
				} else {
					lappend output [lindex $tokens $ri] [lindex $tokens $i]
				}
				set ri {}
			}
		}
	}
	if {$ri != {}} {
		if {[lindex $tokens end]-[lindex $tokens $ri] > 1} {
				lappend output [lindex $tokens $ri]:[lindex $tokens end]
			} else {
				lappend output [lindex $tokens $ri] [lindex $tokens end]
			}
	} else {
		lappend output [lindex $tokens end]
	}
	return [join $output " "]
}