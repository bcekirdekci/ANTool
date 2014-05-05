package provide antool::utils 1.0
namespace eval ::antool::utils {
	namespace export *
}

proc ::antool::utils::unarg {key def {var args}} {
	upvar 1 $var ags
	set key [string map {* \\w*} $key]
	# TODO: -nocase
	set i [lsearch -regexp $ags ^$key\$]
	if {$i == -1} {
		return $def
	} else {
		set vv [lindex $ags [expr $i+1]]
		set ags [lreplace $ags $i [expr $i+1]]
		return $vv
	}
}

proc ::antool::utils::unarg2 {type var key {def never_never_can_happen} } {
	upvar 1 args ags
	upvar 1 $var vvar
	
	set key [string map {* \\w*} $key]
	# TODO: -nocase
	set i [lsearch -regexp $ags ^$key\$]
	if {$type eq "arg"} {
		if {$i == -1 && $def ne "never_never_can_happen"} {
			set vvar $def
			return 1
		} elseif {$i != -1} {
			set vv [lindex $ags [expr $i+1]]
			set ags [lreplace $ags $i [expr $i+1]]
			set vvar $vv
			return 1
		}
		return 0
	} elseif {$type eq "flag"} {
		if {$i == -1 && $def ne "never_never_can_happen"} {
			set vvar 0
		} else {
			set vvar 1
			set ags [lreplace $ags $i $i]
			return 1
		}
		return 0
	} else {
		::antool::utils::error "type is $type"
	}
}

proc ::antool::utils::unflag {key {var args}} {
	upvar 1 $var ags
	set key [string map {* \\w*} $key]
	# TODO: -nocase
	set i [lsearch -regexp $ags ^$key\$]
	if {$i == -1} {
		return 0
	} else {
		set ags [lreplace $ags $i $i]
		return 1
	}
}

proc ::antool::utils::isargs {{var args}} {
	upvar 1 $var ags
	set i [lsearch $ags "--"]
	if {$i == 0} {
		return
	} elseif {$i > 0} {
		set ags [lrange $ags 0 $i]
	} 
	# TODO: -nocase
	set i [lsearch -all -regexp $ags ^-\\w*\$]
	if {[llength  $i] > 0} {
		set rem {}
		foreach ii $i {
			append rem [lindex $ags $ii]
		}
		error "Keys are remaining in args: $rem"
	}
}

#catch {close [open ulog.txt w]} ret
proc ::antool::utils::ulog {args} {
	#catch {set f [open ulog.txt a]; puts $f $args;close $f} ret
	set f [open ulog.txt a]
	puts $f $args
	close $f
}

proc ::antool::utils::call_stack {} {
    set str ""
    for {set i [expr [info level]-2]} {$i > 0} {incr i -1} {
        append str "\t<<< [info level $i]"
    }
    return $str
}

proc ::antool::utils::error {args} {
	set str "ERROR: [join $args " "] [::antool::utils::call_stack]"
	::error $str
}