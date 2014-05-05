## \file antool.tcl
# Main file with ANTool sources 

package provide antool 0.1

package forget antool::utils
package require antool::utils

package forget antool::query
package require antool::query

package forget antool::list
package require antool::list


## Namespace \c antool is the scope where all ANTool TCL functions is situated. Functions dedicated for internal use are started with underscore "_". 
# All other fuctions are imported to global space for users. The simplest way to load ANTool to Ansys environment is to call ANT macros

namespace eval antool {
	namespace export *
	variable current_window 1
	variable max_num_of_windows 5
	set fonts(default,font)		"Courier"
	set fonts(default,size)		15
	set	fonts(default,italic)	0
	set fonts(default,angle)	0
	set fonts(default,weight)	0.3
	set coord_tol			1e-2
	set ang_tol			1e-1
	set coord_big			1e10
	set _PI				[expr acos(-1)]
	set ang_unit		DEG 
	set _comp_stack_number 0
	set _comp_stack_name _STACK
	array set default_colormap {
	 	0,name	black 			0,sname  blac 	0,rgb 	"0,0,0"
		1,name	magenta-red		1,sname  mred	1,rgb 	"100,0,61"
		2,name	magenta			2,sname	 mage	2,rgb 	"100,0,100"
		3,name	blue-magenta	3,sname  bmag	3,rgb 	"63,0,100"
		4,name	blue			4,sname	 blue	4,rgb 	"0,0,100"
		5,name	cyan-blue		5,sname  cblu	5,rgb 	"0,63,100"
		6,name	cyan			6,sname  cyan	6,rgb 	"0,100,100"
		7,name	green-cyan		7,sname  gcya	7,rgb 	"0,100,63"
		8,name	green			8,sname  gree	8,rgb 	"0,100,0"
		9,name	yellow-green 	9,sname  ygre	9,rgb 	"70,100,0"
		10,name yellow			10,sname yell	10,rgb 	"100,100,0"
		11,name orange			11,sname oran	11,rgb 	"100,57,0"
		12,name red				12,sname red	12,rgb 	"100,0,0"
		13,name	dark-gray		13,sname dgra	13,rgb 	"63,63,63"
		14,name light-gray		14,sname lgra	14,rgb 	"78,78,78"
		15,name white			15,sname white	15,rgb 	"100,100,100"
	}	
	
	array set colormap {}
	set debug_mode 0
	set version 0.1
	set logfilename "antool_log.txt"
	set antool_console_cmd_history {}
	set antool_console_cmd_current {}
	set antool_console_to_show_line_numbers	5
	set antool_console_max_history		10
}

## \c _init is used every time when ANTool is loaded to Ansys executable environment. It sets up next things:
# - shows the ANTool Console
# - inspects current state of Ansys environment (color scheme, for example)
# - sets angular units to \c antool::ang_unit
# - sets selection tolerance to \c antool::coord_tol

proc antool::_init {args} {
	variable coord_tol
	variable ang_unit
	colormap -inspect
	ans_sendcommand "SELTOL, $coord_tol"
	::antool::list::_init
	#ans_ang_tol	
	angular_unit $ang_unit
	if {![env -batch]} {
		_console2 -show
	}
	
}

## this function is not used anywhere

proc antool::logit {args} {
	set noprint [::antool::utils::unarg -nop*		"none"]
	
	if {$noprint ne "none"} {
		if {![::antool::env -batch]} {
			::apdl::noprint $noprint	
		}
	}
}

## \c apdl function provide an ability to easily send multiline script to Ansys. The function catches any Ansys WARNING/ERROR message while playing script 
# and throw an error if any occurs, untill -nowarning/-noerror flags are provided. Flag -important means that Ansis will exit with fatal error (exit code 15) if any wrong is happened.
#
# Example of simply use:
#~~~{.tcl}
#	apdl {
#		K,1000001,,,
#		K,1000002,,,dz
#	} -nowarning -important
#~~~
# As you see the implementation don't differ from the usual way. APDL parameters can be used as usual.
#
# Next example shows how a substitution on a TCL level can be implemented:
#~~~{.tcl}
#	apdl "ESIZE,$es"
#	apdl "VSBA,ALL,$mida"
#~~~
#
proc antool::apdl {cmd args} {
	set nowarn [::antool::utils::unflag -nowarn*	]
	set noerr [::antool::utils::unflag -noerr*	]
	set import [::antool::utils::unflag -imp*	]
	foreach str [split $cmd "\n"] {
		if {$str eq ""} continue
		set str [string trim $str]
		puts "send cmd: $str"
		if {[catch {ans_sendcommand $str} res]} {
			puts "Answer is: $res"
			if {[string match "*warning*" $res] && $nowarn == 0} {
				::antool::utils::error  "antool::apdl: Command \"$str\" throw WARNING \"$res\""
				if {$import} {
					antool::msg -lev FATAL -str "FATAL!"
				}
				return
			} elseif {[string match "*error*" $res] && $noerr == 0} {
				::antool::utils::error  "antool::apdl: Command \"$str\" throw ERROR \"$res\""
				if {$import} {
					antool::msg -lev FATAL -str "FATAL!"
				}
				return
			}
		}
	}
}

## \c _console is the service function. It initializates and shows ANTool Console window. It also provide functionality to execute TCL commands.
# \param -show -- shows the console
# \param -do_antool -- execute TCL script in Ansys's TCL interpreter
proc antool::_console {args} {
	set show [::antool::utils::unflag -sho*		]
	set do_a [::antool::utils::unflag	-do_ant*	]
	
	if {$show} {
		catch {destroy .antool_console}
		set w [toplevel .antool_console]
		wm title $w "ANTool Console"
		set f1 [frame $w.f1]
		set f2 [frame $w.f2]
		set f3 [frame $w.f3]
		
		pack $f1 $f2 $f3 -side top -fill both -expand yes
		
		set ::sshcmd ""
		listbox $f2.sshbox -height 5 -width 70 -listvariable ::antool::antool_console_cmd_history
		entry $f3.sshentry -textvar ::antool::antool_console_cmd_current
		
		pack $f2.sshbox -side top -fill both -expand yes
		pack $f3.sshentry -side left -fill x -pady 2 -anchor w -expand yes
		wm protocol $w WM_DELETE_WINDOW "destroy $w"
		bind $w <Return> [list ::antool::_console -do_antool]
	}
	
	if {$do_a} {
		if {[catch {namespace eval :: $::antool::antool_console_cmd_current} res]} {
			error $res
		} else {
			lappend ::antool::antool_console_cmd_history $res
		}
		#foreach c [split $::antool::antool_console_cmd_current \n] {}
		#	lappend ::antool::antool_console_cmd_history $c
		#	catch {eval $c} res
		#	lappend ::antool::antool_console_cmd_history $res
		#{}	
	}
}

proc antool::_console2 {args} {
	set show [::antool::utils::unflag -sho*		]
	set do_a [::antool::utils::unflag	-do_ant*	]
	set do_multi_a [::antool::utils::unflag	-do_multi_ant*	]
	set wc [::antool::utils::unarg	-cmd*	{}]
	set ws [::antool::utils::unarg	-cshow*	{}]
	set wsc [::antool::utils::unarg	-scroll*	{}]
	variable antool_console_to_show_line_numbers
	if {$show} {
		catch {destroy .antool_console2}
		set w [toplevel .antool_console2 -height 300 -width 600]
		wm title $w "ANTool console"
		wm attributes $w -topmost 1
		##=========================================================
		##	Create a tabnotebook iwidget
		##=========================================================
		##
		#	-width 350
		#	-height 250
		#.antool_console2.tn.fu.t
		set tb [iwidgets::tabnotebook $w.tn \
			-tabpos n \
			-angle 0 \
			-width 600 \
			-height 300 \
			-background #336699 \
			-tabbackground white \
			-foreground white \
			-bevelamount 4 \
			-gap 3 \
			-margin 6 \
			-tabborders 0 \
			-backdrop #666666 ]

		##
		##	Add some tabs
		##
		#ANT APDL WARN ERR



		set tb_ANT	[$tb add -label "ANTool"]
		frame $tb_ANT.fu -bd 2
		frame $tb_ANT.fl -bd 2 -height 12p
		pack $tb_ANT.fu -expand 1 -fill both
		pack $tb_ANT.fl -expand 0 -fill x


		set ANT_show [text $tb_ANT.fu.t -yscrollcommand "$tb_ANT.fu.scroll set" -setgrid true \
				-width 40 -height 10 -wrap word]
		scrollbar $tb_ANT.fu.scroll -command "$tb_ANT.fu.t yview"
		pack $tb_ANT.fu.scroll -side right -fill y
		pack $tb_ANT.fu.t -expand yes -fill both

		# Set up the tags 
		$ANT_show tag configure cmd -font \
			{-family courier -size 12 -weight bold} -foreground blue
		$ANT_show tag configure ans -font \
			{-family courier -size 10}
		#$ANT_show tag configure big -font {-family helvetica -size 24 -weight bold}
		#$ANT_show tag configure color1 -foreground red
		#$ANT_show tag configure sunken -relief sunken -borderwidth 1
		#$ANT_show tag bind Ouch <1> {.t insert end "Ouch! "}

		# Now insert text that has the property of the tags
		$ANT_show insert end "Welcome to ANTool console! v0.1\n"
		#$ANT_show insert end "sel -q \"all.elem.type(1 2 3 4).real(20)\"\n" cmd
		#$ANT_show insert end "Selected 403 elements\n" ans
		pack $tb -fill both -expand 1


		set ANT_cmd [text $tb_ANT.fl.t -yscrollcommand "$tb_ANT.fl.scroll set" -setgrid true \
				-width 40 -height 1  -undo 1 -wrap none]
		set ANT_cmd_scroll [scrollbar $tb_ANT.fl.scroll -command "$tb_ANT.fl.t yview"]
		pack $tb_ANT.fl.t -expand 1 -fill x -side left

		# Set up the tags 
		$ANT_cmd tag configure cmd -font \
			{-family courier -size 12 -weight bold} -foreground blue
			
		pack $tb -fill both -expand 1

		$tb select 0


		bind $ANT_cmd <Shift-KeyPress-Return> "::antool::_console2 -do_ant  -cmd $ANT_cmd -cshow $ANT_show -scroll $ANT_cmd_scroll"
		bind $ANT_cmd <KeyPress-Return> "::antool::_console2 -do_multi_ant  -cmd $ANT_cmd -cshow $ANT_show -scroll $ANT_cmd_scroll"
		bind $ANT_cmd <Control-KeyPress-v> "::antool::_console2 -do_multi_ant  -cmd $ANT_cmd -cshow $ANT_show -scroll $ANT_cmd_scroll"

		set tb_APDL	[$tb add -label "APDL"]
		set tb_LOG	[$tb add -label "Log"]
		set tb_WARN	[$tb add -label "Warnings"]
		set tb_ERR	[$tb add -label "Errors"]
	}
	
	if {$do_a} {
	
		set answer ""
		set cmd [$wc get 0.0 end]
		if {[catch {namespace eval :: $cmd} res]} {
			error $res
		} else {
			set answer $res
			if {$answer ne ""} {
				if {[string index $answer end] ne "\n"} {
					append answer "\n"
				}
			}
		}
		append answer "----------------------------------\n"
		#eval cmds
		#set answer "Answer\n"
		set lcmd [split $cmd "\n"]
		#trim empty lines from start and end
		set count 0
		while {1} {
			if {[lindex $lcmd $count] ne ""} {
					break
			}
			incr count
		}
		if {$count != 0} {
			set lcmd [lrange $lcmd $count end	]
		}
		set lencmd [llength $lcmd]
		set count [expr $lencmd-1]
		while {1} {
			if {[lindex $lcmd $count] ne ""} {
				break
			}
			incr count -1
		}
		
		if {$count != $lencmd-1} {
			set lcmd [lrange $lcmd 0 $count]	
			set lencmd [llength $lcmd]
		}
		## end trim
		
		
		if {$lencmd > $antool_console_to_show_line_numbers} {
				set cmd [join [lrange $lcmd 0 [expr $antool_console_to_show_line_numbers-1]] "\n"]
				append cmd "\n...\n"
		} else {
				set cmd [join $lcmd "\n"]
				append cmd "\n"
		}
		
		if {![catch {pack info $wsc}]} {
			pack forget $wsc
			$wc configure -height 1
		}
		$wc delete 0.0 end
	#	$wc delete 1.0 2.1
		$ws insert end $cmd cmd
		$ws insert end $answer ans
		$ws yview end
		#puts [$wc index insert]
		$wc mark set insert 1.0
		#puts [$wc index insert]
		$wc mark set current 1.0 
	} elseif {$do_multi_a} {
		set cmd [$wc get 1.0 end]
		if {[string index $cmd 0] eq "\n"} {
			$wc delete 1.0	
		}
		set lcmd [split $cmd "\n"]
		set lencmd [llength $lcmd]
		if {[catch {pack info $wsc}]} {
			#not yet displayed	
			pack $wsc -side right -fill y
		}
		set how_lines $lencmd
		if {$lencmd > $antool_console_to_show_line_numbers} {
			set lencmd $antool_console_to_show_line_numbers
		}
		if {$lencmd < 3} {
			set lencmd 3	
		}
		$wc configure -height $lencmd
	}
}






proc do_it {wc ws wsc args} {
	
}

proc do_multiline {wc ws wsc args} {
	
}


## \c env return values from Ansys state variables (for example: jobname, run mode, etc.)
# \param -jobname -- return name of the current jobname
# \param -batch -- return "1" if Ansys is running in batch mode, otherwise return "0"
#
# Example of use:
#~~~{.tcl}
#	puts "The jobname of the current task is [env -jobname]"
#~~~
#
proc antool::env {args} {
	set jobname 	[::antool::utils::unflag -job*]
	set batch		[::antool::utils::unflag -bat*]

	if {$jobname} {
		return [string trim [ans_getvalue ACTIVE,0,JOBNAM]]
	} 
	
	if {$batch} {
		set res [ans_getvalue active,,int,0	]
		if {$res == 0} {
			return 1
		} elseif {$res == 2} {
			return 1
		} else {
			return 0
		}
	}
}

## \c pic function is for render to a file. The main difference of the standart APDL functions is that in \c pic one can save an image with custom name (not just jobname001.png). 
# This function works well either in GUI mode or in batch mode. But be aware! In the batch mode the font and font size of labels and annotations are the constant. And the height of the image is not greater than 2400 pixels.
# The aspect ration is locked by Ansys, it's 4:3. So when you provide -height parameter of your image, the width will be 1.33*height. PNG is the only format which can be used in the batch mode. In the GUI mode one can use any format maintained by /UI command.
# \param -file -- filename of the image (with or without of an extension)
# \param -format -- format of the image. Default: "png"
# \param -height -- height of the image. Default: 800
#
# Example of making two images of countour of U,SUMM with different views, with a title:
#~~~{.tcl}
#title -title "Fmax = $fmax N, goal = $goal"
#contour -node -comp "U,SUM" -scale 1.0 -undef "edge"
#view -load "../../view1"
#pic -file summ_disp_view1 -height 2000
#view -load "../../view2"
#pic -file summ_disp_view2 -height 2000
#~~~
proc antool::pic {args} {
	
	global tk_borderwidth
    global tk_titleheight
    global tk_posinternal
	
	set file 	[::antool::utils::unarg -file "none"]
	set format	[::antool::utils::unarg -format "png"]
	set height	[::antool::utils::unarg -height 800]
	
	set ratio 1.33
	set h_min 266
	set h_max 2410
	#warning if no in range
	
	set format [string tolower $format]
	
	if {[file extension $file] eq ""} {
		set file $file.$format
	}
	
	set jobname [env -jobname]
	#no picname increment
	ans_sendcommand )/DEV,PSFN,NINC
	
	if {[env -batch]} {
		switch -- $format {
			png {
				ans_sendcommand "PNGR,COMP,1,-1"
				ans_sendcommand "PNGR,ORIENT,HORIZ"
				ans_sendcommand "PNGR,COLOR,2"
				ans_sendcommand "PNGR,TMOD,1"
				ans_sendcommand "/GFILE,[expr $height-10],"
				#draw
				ans_sendcommand "/SHOW,PNG,,0"  
				ans_sendcommand "/REPLOT"
				ans_sendcommand "/SHOW,CLOSE"
				
				#ans_sendcommand "/DEVICE,VECTOR,0"
			} 
			default {
				 ::antool::utils::error  "format $format not supported in batch mode"	
			}
		}
	} else {
		 
		if {$tk_posinternal} {
        	set bd $tk_borderwidth
        	set th $tk_titleheight
       	} else {
          	set bd 0
          	set th 0
      	}
		
		set xpos [expr [ans_getvalue active,,win,grph,xpos]+$bd]
		set ypos [expr [ans_getvalue active,,win,grph,ypos]+$bd+$th]
		set xpos $bd
		set ypos $bd
		set winw [ans_getvalue active,,win,grph,width]
		set winh [ans_getvalue active,,win,grph,height]
		 if {[ans_getvalue common,,mccom,,int,16]} {
             catch {ans_sendcommand )/ui,wsize,$xpos,$ypos,[expr $height*$ratio],$height} err
          } else {
             ::AnsysGUI::AnsysGraphics::sizeWindow [expr $height*$ratio] $height
             catch {ans_sendcommand )/ui,wsize,$xpos,$ypos,[expr $height*$ratio],$height} err
          }
		
		#::AnsysGUI::AnsysGraphics::sizeWindow [expr $height*$ratio] $height
		#ans_sendcommand )/ui,wsize,$xpos,$ypos,[expr $height*$ratio],$height
		ans_sendcommand )/UI,COPY,SAVE,$format,GRAPH,COLOR,NORMAL,PORTRAIT,ON,-1	
		#::AnsysGUI::AnsysGraphics::sizeWindow $winw $winh
		#ans_sendcommand )/ui,wsize,$xpos,$ypos,$winw,$winh
		 if {[ans_getvalue common,,mccom,,int,16]} {
             catch {ans_sendcommand )/ui,wsize,$xpos,$ypos,$winw,$winh} err
          } else {
             ::AnsysGUI::AnsysGraphics::sizeWindow $winw $winh
             catch {ans_sendcommand )/ui,wsize,$xpos,$ypos,$winw,$winh} err
          }
	}
		
	#on the case if the image not already drawn..
	if {0} {
		after 100
		set files [glob -nocomplain -types f $jobname ${jobname}*.$format]
		set ids [lsearch -regexp -all -not $files [join $prefiles |]]
		if {[llength $ids] != 1} {
			 ::antool::utils::error  "Here is more than 1 new pic file (or nothing)"
		}
		
		while {[file size $latestf] < 100} {
			after 100 
		}
		if {$format eq "png"} {
			while {1} {
				set file [lindex $files $ids]
				set f [open $file r]
				seek $f -8 end
				set symb [read $f 4]
				close $f
				if {$symb eq "IEND"} {
					break
				}
				after 100
			}
		}
	}
	
	if {[llength [file split $file]] > 1} {
		set dir [eval [concat file join [lrange [file split $file] 0 end-1]]]
		file mkdir $dir
	}
	
	#turn on picname increment
	ans_sendcommand )/DEV,PSFN
	update
	file rename -force -- $jobname.$format $file
}

## \c substep command handles the work with loadsteps and substeps. This function is useful in *postprocessing*. Loadsteps is the solution "checkpoint" :) when the conditions of the solution could be changed (for example BCs). 
# Substeps is intermidiate point located between loadsteps needed for convergense in the incremental method of solution. Ansys also operates with solution sets. Every converged substep is a solution set.
# Numeration of solution sets is incremental, while substeps star from 1 for every new loadstep.
#
# **Actions**:
#	- -num -- returns the number of substeps in the loadstep. Inputs: -ls **l**
#	- -set **n** -- sets current loadstep number to **n**. **n** can be step number or: *last* -- last substep in a loadstep, *prev* -- a previus substep from the current substep, *converged* -- last converged substep in a loadstep. Inputs: -ls **l**
#	- -get -- returns the current substep number
# \param -ls **l** -- loadstep number. Default: current
# \param -num -- returns the number of substeps in the loadstep.
# \param -get -- returns the current sustep number

proc antool::substep {args} {
	set ls 		[::antool::utils::unarg  -ls "current"	]
	set list	[::antool::utils::unflag -list			]
	set num		[::antool::utils::unflag -num			]
	set get		[::antool::utils::unflag -get			]
	set set		[::antool::utils::unarg  -set "none"	]
	set settime	[::antool::utils::unarg  -settime "none"	]
	set time	[::antool::utils::unarg  -time "none"	]
	set freq	[::antool::utils::unarg -freq "none"	]
	set isconv	[::antool::utils::unflag -isconverged 		]
	
	if {$ls eq "current"} {
		set ls [ans_getvalue ACTIVE,0,SET,LSTP]
		if {$ls == 0} {
			set ls 1
		}
		puts "ls = $ls"
	}
	
	if {$isconv} {
		ans_sendcommand "SET,$ls,LAST"
		set sbst [ans_getvalue ACTIVE,0,SET,SBST]
		if {$sbst >= 9999} {
			#this step is not converged
			return 0
		} else {
			return 1
		}
	}
	
	if {$list} {
		set li {}
		set n [substep -num]
		for {set i 1} {$i <= $n} {incr i} {
			lappend li $i
		}
		return $li
	} elseif {$num} {
		set first_set [ans_getvalue ACTIVE,0,SET,NSET,FIRST,$ls]
		set last_set [ans_getvalue ACTIVE,0,SET,NSET,LAST,$ls]
		if {![substep -isconverged]} {
			return [expr $last_set-$first_set]
		} else {
			return [expr $last_set-$first_set+1]
		}
	} elseif {$get} {
		return [ans_getvalue ACTIVE,0,SET,SBST]
	} elseif {$set ne "none"} {
		if {$set eq "last"} {
			#set set [substep -ls $ls -num]
			#puts "SET,$ls,$set"
			ans_sendcommand "SET,$ls,LAST"
		} elseif {$set eq "prev"} {
			#set set [expr [substep -ls $ls -set "last"]-1]
			puts "SET,PREV"
			ans_sendcommand "SET,PREV"
		} elseif {$set eq "converged"} {
			substep -ls $ls -set "last"
			set sbst [ans_getvalue ACTIVE,0,SET,SBST]
			if {$sbst >= 9999} {
				#this step is not converged
				substep -ls $ls -set prev
			}
		} else {
			puts "SET,$ls,$set"
			ans_sendcommand "SET,$ls,$set"
		}
	} elseif {$time ne "none"} {
		if {[string match -nocase "cur*" $time]} {
			set tim [ans_getvalue ACTIVE,0,SET,TIME]
		} else {
			set old [substep -get]
			substep -set $time
			set tim [ans_getvalue ACTIVE,0,SET,TIME]
			substep -set $old
		}
		return $tim
	} elseif {$freq ne "none"} {
		if {[string match -nocase "cur*" $freq]} {
			set freq [ans_getvalue ACTIVE,0,SET,SBST]	
		} 
		return [ans_getvalue ACTIVE,0,SET,FREQ]
		#return [ans_getvalue MODE,$freq,FREQ]
	} elseif {$settime ne "none"} {
		apdl "SET,,,,,$settime"
		if {[substep -time curr] != [ans_evalexpr $settime]} {
			::antool::utils::error "Here is no time $settime"
		}
	} else {
		 ::antool::utils::error  "commads: -list, -num, -get, -set"
	}
}

#contour -node -range "0,2000" -comp "S,EQV" -undef edge
proc antool::contour {args} {
	set node 	[::antool::utils::unflag		-nod*			]
	set elem 	[::antool::utils::unflag		-elem			]
	set comp 	[::antool::utils::unarg		-comp 	"none"	]
	set scale	[::antool::utils::unarg		-scale "auto"	]
	set undef	[::antool::utils::unarg		-undef "none"	]; #edge, elem
	set range	[::antool::utils::unarg		-range "auto"	]; # "min,max,[nsteps]"
	
	set def_nsteps 9
	
	if {$scale eq "auto"} {
		ans_sendcommand "/DSCALE,ALL,AUTO"
	} else {
		if {$scale == 0} {
			set scale 0.0
		}
		ans_sendcommand "/DSCALE,ALL,$scale"
	}
	
	if {$comp eq "none"} {
		 ::antool::utils::error  "No component specified (use -comp)"
	}
	
	if {$undef eq "none"} {
		set kund 0
	} elseif {$undef eq "edge"} {
		set kund 2
	} elseif {$undef eq "elem"} {
		set kund 1
	} else {
		 ::antool::utils::error  "Unknown undef = $undef"
	}
	
	if {$range eq "auto"} {
		ans_sendcommand "/CONT,1,$def_nsteps,AUTO"	
	} else {
		set lrange [split $range ","]
		if {[llength $lrange] == 3} {
			ans_sendcommand "/CONT,1,[lindex $lrange 2],[lindex $lrange 0],,[lindex $lrange 1]"	
		} elseif {[llength $lrange] == 2} {
			ans_sendcommand "/CONT,1,$def_nsteps,[lindex $lrange 0],,[lindex $lrange 1]"	
		} else {
			 ::antool::utils::error  "range $range is incorrect"	
		}
	}
	
	if {$node} {
			#puts "PLNSOL,$comp,$kund"
			apdl "PLNSOL,$comp,$kund" -nowarning
	} elseif {$elem} {
		 ::antool::utils::error  "Not now"
	} else {
		 ::antool::utils::error  "Nodal or elem plot? (use -node or -elem)"
	}
}

proc antool::view {args} {
	variable current_window
	set wind	[::antool::utils::unarg	-w*			"none"	]
	set vsave	[::antool::utils::unarg	-sa*		"none"	]
	set vload	[::antool::utils::unarg	-lo*		"none"	]
	set view	[::antool::utils::unarg	-at			"none"	]
	set focus 	[::antool::utils::unarg	-to			"none"	]
	set dist	[::antool::utils::unarg	-di*		"none"	]
	set angl	[::antool::utils::unarg	-an*		"none"	]
	set fit 	[::antool::utils::unflag	-fit*				]
	set get		[::antool::utils::unarg	-get		"none"	]
	
	
	if {$wind ne "none"} {
		set num $wind
	} else {
		set num $current_window
	}
	
	#/VIEW
	if {$view ne "none"} {
		if {$view eq "-x"} {
			set view "-1.0,0.0,0.0"
		} elseif {$view eq "+x" || $view eq "x"} {
			set view "1.0,0.0,0."
		} elseif {$view eq "-y"} {
			set view "0.0,-1.0,0.0"
		} elseif {$view eq "+y" || $view eq "y"} {
			set view "0.0,1.0,0.0"
		} elseif {$view eq "-z"} {
			set view "0.0,0.0,-1.0"
		} elseif {$view eq "+z" || $view eq "z"} {
			set view "0.0,0.0,1.0"
		} 
		ans_sendcommand "/VIEW,$num,$view"
	}
	
	if {$focus ne "none"} {
		#TODO: 	
	}
	
	if {$dist ne "none"} {
		set key 0
		if {[string index $dist 0] eq "d"} {
			set key 1
			set dist [string range $dist 1 end]
		}
		ans_sendcommand "/DIST,$num,$dist,$key"
	}
	
	if {$angl ne "none"} {
		set key 0
		if {[string index $angl 0] eq "d"} {
			set key 1
			set angl [string range $angl 1 end]
		}
		ans_sendcommand "/ANGLE,$num,,$key"
	}
	
	if {$fit} {
		ans_senfcommand "/AUTO,$num"
	}
		
	if {$vsave ne "none"} {
		if {[file extension $vsave] eq ""} {
			set vsave $vsave.view
		}
		set file [open $vsave w]
			puts $file "NUM_OF_WINDOW=$num"
			puts $file "/ANGLE,NUM_OF_WINDOW,[ans_getvalue GRAPH,$num,ANGLE],,0"
			puts $file "/VIEW,NUM_OF_WINDOW,[ans_getvalue GRAPH,$num,VIEW,X],[ans_getvalue GRAPH,$num,VIEW,Y],[ans_getvalue GRAPH,$num,VIEW,Z]"
			puts $file "/DIST,NUM_OF_WINDOW,[ans_getvalue GRAPH,$num,DIST],0"
			puts $file "/FOCUS,NUM_OF_WINDOW,[ans_getvalue GRAPH,$num,FOCUS,X],[ans_getvalue GRAPH,$num,FOCUS,Y],[ans_getvalue GRAPH,$num,FOCUS,Z],0"
			puts $file "NUM_OF_WINDOW="
		close $file
	} elseif {$vload ne "none"} {
		if {[file extension $vload] eq ""} {
			set vload $vload.view
		}
		set file [open $vload r]
			set str [gets $file]
			ans_sendcommand "NUM_OF_WINDOW=$num"
			while {![eof $file]} {
				ans_sendcommand [gets $file]
			}
		close $file
	}
	
	if {$get ne "none"} {
		switch -glob -nocase $get {
			at { return [list [ans_getvalue GRAPH,$num,VIEW,X] [ans_getvalue GRAPH,$num,VIEW,Y] [ans_getvalue GRAPH,$num,VIEW,Z]]}
			to { return [list [ans_getvalue GRAPH,$num,FOCUS,X] [ans_getvalue GRAPH,$num,FOCUS,Y] [ans_getvalue GRAPH,$num,FOCUS,Z]]}
			di* { return [ans_getvalue GRAPH,$num,DIST]}
			an* {return [ans_getvalue GRAPH,$num,ANGLE]}
			default { ::antool::utils::error  "What you want to get? (at, to, dist, angle)"}
		}
	}
}

#not work
#window -window 1 -current -active 1
#window -window 2 -position "-1,-1,0,0"
proc antool::window {args} {
	variable current_window
	set active 	[::antool::utils::unarg	-act*	"none"		]
	set num		[::antool::utils::unarg 	-w*		"current"	]
	set	cur		[::antool::utils::unflag 	-cur*	"none"		]
	set pos		[::antool::utils::unarg	-pos*	"none"		]
	set dele	[::antool::utils::unflag	-del*				]
	set get		[::antool::utils::unarg	-get	"none"		]
	
	if {$cur} {
		set current_window $num
	}
	
	if {$num eq "current"} {
		set num $current_window
	}
	
	if {$active} {
		foreach w $max_num_windows {
			if {[ans_getvalue GRAPH,$w,ACTIVE] == 1} {
				return $w
			}
		}
	}
	
	
}
#In batch mode: Courier and Helvetica
#font -legend -annotation -size 16
proc antool::fonts {args} {
	variable fonts
	set legend		[::antool::utils::unflag	-leg*			]
	set entity		[::antool::utils::unflag	-ent*			]
	set annotation	[::antool::utils::unflag	-ann*			]
	set font		[::antool::utils::unarg 	-fon*	"none"	]
	set size		[::antool::utils::unarg	-si*	"none"	]
	set weight		[::antool::utils::unarg	-wei*	"none"	]
	set italic		[::antool::utils::unarg	-it*	"none"	]
	set angle		[::antool::utils::unarg	-ang*	"none"	]
	
	#add platform independency!
	
	foreach t {legend entity annotation} k {1 2 3} {
		if {[set $t]} {
			foreach _t {f s w i a} par {font size weight italic angle} { 
				if {[set $par] ne "none"} {
					set $_t [set $par]
				} elseif {[info exist fonts($t,$par)]} {
					set $_t $fonts($t,$par)
				} else {
					set $_t $fonts(default,$par)
				}
				set fonts($t,$par) [set $_t]
			}
			puts "font: /DEVICE,FONT,$k,$f,[expr int($w*1000.0)],$a,$s,,$i"
			ans_sendcommand	"/DEVICE,FONT,$k,$f,[expr int($w*1000.0)],$a,$s,,$i"
		}
	}
}

proc antool::title {args} {
	set title 	[::antool::utils::unarg	-t*		"none"]
	set sub1	[::antool::utils::unarg	-s*1	"none"]
	set sub2	[::antool::utils::unarg	-s*2	"none"]
	set sub3	[::antool::utils::unarg	-s*3	"none"]
	set sub4	[::antool::utils::unarg	-s*4	"none"]
	set get		[::antool::utils::unarg	-get	"none"]
	
	if {$title ne "none"} {
		ans_sendcommand "/TITLE,'$title'"
	}
	foreach s {sub1 sub2 sub3 sub4} n {1 2 3 4} {
		if {[set $s] ne "none"} {
			ans_sendcommand "/STITLE,$n,'[set $s]'"
		}
	}
	
	if {$get ne "none"} {
		switch -nocase -glob -- $get {
		t*	{return [string trim [ans_getvalue ACTIVE,0,TITLE,0]]}
		s*1 {return [string trim [ans_getvalue ACTIVE,0,TITLE,1]]}
		s*2 {return [string trim [ans_getvalue ACTIVE,0,TITLE,2]]}
		s*3 {return [string trim [ans_getvalue ACTIVE,0,TITLE,3]]}
		s*4 {return [string trim [ans_getvalue ACTIVE,0,TITLE,4]]}
		default { ::antool::utils::error  "Don't know title (get=$get). Use title,sub1,sub2,sub3,sub4"}
		}
	}
	
}
#colormap -scheme bright
#pic -file mode1
#colormap -scheme dark
proc antool::colormap {args} {
	variable colormap
	variable default_colormap
	#set scheme	[::antool::utils::unarg	-sch*	"none"	] ;#bright or dark or invert
	set inv		[::antool::utils::unflag	-inv*			]
	set inspect	[::antool::utils::unflag	-ins*			]
	set print	[::antool::utils::unflag	-pr*			]
	set assign	[::antool::utils::unarg	-ass*	"none"	]
	
	set colors_max 16
	if {$inspect} {
		ans_sendcommand "/CMAP,colormap_for_inspect,cmap,,SAVE"
		after 100
		set f [open colormap_for_inspect.cmap r]
		while {![eof $f]} {
			set str [gets $f]
			if {[regexp {^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$} $str dummy ind r g b ]} {
				set colormap($ind,rgb) "$r,$g,$b"
				set def_n [_get_index_by_rgb default_colormap "$r,$g,$b"]
				if {$def_n>-1} {
					set colormap($ind,name) $default_colormap($def_n,name)
					set colormap($ind,sname) $default_colormap($def_n,sname)
				}
			}
		}
		close $f
		file delete -force colormap_for_inspect.cmap
	}
	
	if {$assign ne "none"} {
		foreach {ind rgb} [split $assign] {break}
		if {![regexp {^\d+,\d+,\d+$} $rgb]} {
			set d_ind [_get_index_by_colorname default_colormap $rgb name]
			if {$d_ind == -1} {
				set d_ind [_get_index_by_colorname default_colormap $rgb sname]
				if {$d_ind == -1} {
					 ::antool::utils::error  "Cant find color $rgb."
				}
			}
			set rgb $default_colormap($d_ind,rgb)
		} 
		set colormap($ind,rgb) $rgb
		set def_n [_get_index_by_rgb default_colormap $rgb]
		if {$def_n>-1} {
			set colormap($ind,name) $default_colormap($def_n,name)
			set colormap($ind,sname) $default_colormap($def_n,sname)
		}
		puts "assign index $ind rgb: $rgb"
		ans_sendcommand "/RGB,INDEX,$rgb,$ind"
	}
	
	if {$print} {
		puts "Current colormap:\nINDEX\tR\tG\tB\tNAME\tSHORT"
		for {set i 0} {$i < $colors_max} {incr i} {
			puts "$i\t[join [split $colormap($i,rgb) ,] \t]\t$colormap($i,name)\t$colormap($i,sname)"
		}
	}
	if {$inv} {
		set n_black [_get_index_by_colorname colormap black]
		set n_white [_get_index_by_colorname colormap white]
		if {$n_black != -1 && $n_white != -1} {
			colormap -assign "$n_black white"
			colormap -assign "$n_white black"
		}
		#parse /COLOR,STAT to find color indexes for background and for text, - it's impossible (((
	}
}

proc antool::size {args} {
	if {[::antool::utils::unarg2	arg lines -line*]} {
		::antool::utils::unarg2 arg	size 	-size*				""
		::antool::utils::unarg2	arg	angsize	-angs*				""
		::antool::utils::unarg2	arg	ndiv	-ndiv*				""
		::antool::utils::unarg2	arg	bias	-(bia*|spac*)		""
		::antool::utils::unarg2	arg	layer1	-layer1				""
		::antool::utils::unarg2	arg	layer2	-layer2				""
		::antool::utils::isargs
		comp -push all
			::antool::_parse_entity $lines -sel
			apdl "LESIZE,ALL,$size,$angsize,$ndiv,$bias,1,$layer1,$layer2"
		comp -pop
	
	} elseif {[::antool::utils::unarg2	arg flp -fl*]} {
		::antool::utils::isargs
		comp -push L
			set linelst [::antool::_parse_entity $flp -sel]
			foreach l [list_selection -line] {
				set _z3 [ans_getvalue "LINE,$l,ATTR,NDNX"]
				set _z4 [ans_getvalue "LINE,$l,ATTR,SPNX"]
				set _z6 [ans_getvalue "line,$l,attr,kynd"]
				if {$_z3 > 0 && $_z4 != 0} {
					apdl "LESIZE,$l,,,$_z3,1/$_z4,,,,$_z6"	
				}
			}
		comp -pop
	} else {
		::antool::utils::error "Dont know action: $args"
	}
}


#-pat 0_6,+45_1,-45_1,90_6
#TODO: diff thick, diff material
proc antool::layup {args} {
	set pat		[::antool::utils::unarg	-pat*	"none"	]
	set sym		[::antool::utils::unflag	-sym*		]
	set t		[::antool::utils::unarg	-t*	"none"	]
	set sec		[::antool::utils::unarg	-sec*	"auto"	]
	set mat		[::antool::utils::unarg	-mat*	"1"	]
	set ipts	[::antool::utils::unarg	-intp*	"3"	]
	set ang0	[::antool::utils::unarg	-ang0	0	]
	if {$sec eq "auto"} {
		#automatig find first unused section number
		 ::antool::utils::error  "Not now"
	}
	if {$t eq "none"} {
		 ::antool::utils::error  "Thickness of layer (-thick) must be specified"
	}
	ans_sendcommand "sect,$sec,shell,,"
	if {$pat eq "none"} {
		 ::antool::utils::error  "Pattern must be specified"
	}
	set cmds {}
	set toks [split $pat "/"]
	foreach tok $toks {
		set prts [split $tok "_"]
		set angle [lindex $prts 0]
		set pm 0
		if {[string range $angle 0 1] eq "+-"} {
			set angle [string range $angle 2 end]
			set pm 1
		}
		set angle [expr $angle+$ang0]
		if {[llength $prts] == 1} {
			set rep 1	
		} else {
			set rep [lindex $prts 1]
		}
		for {set i 0} {$i < $rep} {incr i} {
			if {$pm} {
				lappend cmds "secdata,$t,$mat,$angle,$ipts"
				lappend cmds "secdata,$t,$mat,-$angle,$ipts"
			} else {
				lappend cmds "secdata,$t,$mat,$angle,$ipts"	
			}
				
		}
	}
	if {$sym} {
		for {set i [expr [llength $cmds]-1]} {$i >= 0} {incr i -1} {
			ans_sendcommand [lindex $cmds $i]	
		}	
	} 
	for {set i 0} {$i < [llength $cmds]} {incr i} {
		ans_sendcommand [lindex $cmds $i]	
	}
	ans_sendcommand "secoffset,MID"   
	ans_sendcommand "seccontrol,,,, , , ,"

}

proc antool::fillet {args} {
	set r	 	[::antool::utils::unarg	-r*	"none"	]
	set kp		[::antool::utils::unarg	-kp	"none"	]

	if {$r eq "none"} {
		 ::antool::utils::error  "Radius must be specified"	
	}
	if {$kp ne "none"} {
		set kplst [_unroll_list $kp]
		ans_sendcommand "CM,_Y,KP"
		ans_sendcommand "CM,_Y1,LINE"
		foreach k $kplst {
			ans_sendcommand "KSEL,S, , , $k"
			ans_sendcommand "LSLK,S"
			set ln [ans_getvalue "LINE,0,COUNT"]
			if {$ln != 2} {
				 ::antool::utils::error  "select only $ln lines!"
			}
			set ln1 [ans_getvalue "LINE,0,NXTH"]
			set ln2 [ans_getvalue "LINE,$ln1,NXTH"]
			ans_sendcommand "LFILLT,$ln1,$ln2,$r, ,"
			ans_sendcommand "CMSEL,A,_Y1"
			ans_sendcommand "CMSEL,S,_Y"
			ans_sendcommand "CM,_Y,KP"
			ans_sendcommand "CM,_Y1,LINE"
		}
		ans_sendcommand "CMSEL,S,_Y1"
		ans_sendcommand "CMSEL,S,_Y"
		ans_sendcommand "CMDELE,_Y"
		ans_sendcommand "CMDELE,_Y1 "
		
		#êîñòûëü!
		#ans_sendcommand "ALLSEL,ALL"
	}
}

#modifies selections
proc antool::linked {args} {
	set lines	[::antool::utils::unflag	-line*		]
	set bykp	[::antool::utils::unarg	-bykp	"none"	]
	
	if {$lines} {
		if {$bykp ne "none"} {
			ans_sendcommand "CM,_Y,KP"
			ans_sendcommand "CM,_Y1,LINE"
			ans_sendcommand "KSEL,S, , ,      $bykp"
			ans_sendcommand "LSLK,S"
			set nl [ans_getvalue "LINE,0,COUNT"]
			set nl_old 0
			while {$nl != $nl_old} {
				ans_sendcommand "KSLL,S  "
				ans_sendcommand "LSLK,S"
				set nl_old $nl
				set nl [ans_getvalue "LINE,0,COUNT"]
			}
			#make list
			set lst [list_selection -lines]
			ans_sendcommand "CMSEL,S,_Y1"
			ans_sendcommand "CMSEL,S,_Y"
			ans_sendcommand "CMDELE,_Y"
			ans_sendcommand "CMDELE,_Y1 "
			return $lst
		} else {
			 ::antool::utils::error  "How Can I find lines??"
		}
	} else {
		 ::antool::utils::error  "What object do you want?"
	}
}

proc antool::fix {args} {
	set comp	[::antool::utils::unarg	-tocomp*	"none"	]
	#set entity	[::antool::utils::unarg	-w		"none"	]
	set fix	[::antool::utils::unarg	-f*		"0 0 0"	]
	if {$comp ne "none"} {
		if {[comp -isname $comp -type 1]} {
			ans_sendcommand "CM,_Y,NODE"
			select -nodes -none
			comp -select -name $comp
			foreach c {UX UY UZ ROTX ROTY ROTZ} f $fix {
				if {$f ne "-" && $f ne ""} {
					ans_sendcommand "D,ALL,$c,$f"	
				}
			}
			ans_sendcommand "CMSEL,S,_Y"
			ans_sendcommand "CMDELE,_Y"
		} else {
			 ::antool::utils::error  "What the comp ($comp), dude??"
		}
	}
}

proc antool::force {args} {
	set comp	[::antool::utils::unarg	-tocomp*	"none"	]
	#set entity	[::antool::utils::unarg	-w		"none"	]
	set force	[::antool::utils::unarg	-f*		"0 0 0"	]
	if {$comp ne "none"} {
		if {[comp -isname $comp -type 1]} {
			ans_sendcommand "CM,_Y,NODE"
			select -nodes -none
			comp -select -name $comp
			foreach c {FX FY FZ} f $force {
				if {$f ne "-" && $f ne ""} {
					ans_sendcommand "F,ALL,$c,$f"	
				}
			}
			ans_sendcommand "CMSEL,S,_Y"
			ans_sendcommand "CMDELE,_Y"
		} else {
			 ::antool::utils::error  "What the comp, dude??"
		}
	}
}

proc antool::list_selection {args} {
	set lines 	[::antool::utils::unflag	-lin*		]
	set kps		[::antool::utils::unflag	-kp*		]
	set nodes	[::antool::utils::unflag	-node*		]
	set area	[::antool::utils::unflag	-area*		]
	set vol		[::antool::utils::unflag	-vol*		]
	set elem	[::antool::utils::unflag	-elem*		]
	set list {}
	
	if {$lines} {
		set ent LINE
	} elseif {$kps} {
		set ent KP
	} elseif {$nodes} {
		set ent NODE
	} elseif {$area} {
		set ent AREA
	} elseif {$vol} {
		set ent VOLU
	} elseif {$elem} {
		set ent ELEM
	} else {
		::antool::utils::error "What the entinty type?"
	}
	
	set nl [ans_getvalue "$ent,0,COUNT"]
	if {$nl == 0} {
		set list {}
	} else {
		set cn 0
		for {set i 0} {$i < $nl} {incr i} {
			set cn [ans_getvalue "$ent,$cn,NXTH"]
			lappend list $cn
		}
	}
	return $list
}

proc antool::_parse_coord_ranges {range args} {
	variable coord_big
	variable coord_tol
	set tol [::antool::utils::unarg -tol*		$coord_tol]
	set res {}
	set eps  1e-3
	foreach tok [split $range ","] {
		set tok [string trim $tok]
		if {[regexp {^([xXyYzZ])\s*([><=]+)\s*(.+)} $tok dummy co op val]} {
			switch $op {
				">" {
					set min $val+$tol*(1.0+$eps)
					set max $coord_big
				}
				"<" {
					set max $val-$tol*(1.0+$eps)
					set min -$coord_big
				}
				"<=" {
					set max $val
					set min -$coord_big
				}
				">=" {
					set min $val
					set max $coord_big
				}
				"=" {
					set min $val
					set max $val
				}
				"==" {
					set min $val
					set max $val
				}
				default {
					 ::antool::utils::error  "Dont know this op! ($op)"
				}
			}
			lappend res $co
			lappend res $min
			lappend res $max
		} else {
			::antool::utils::error "what't the operator? $tok"
		}
	}
	return $res
}

proc antool::_parse_angle_ranges {range args} {
	variable coord_big
	variable coord_tol
	variable ang_tol
	variable _PI
	set tol [::antool::utils::unarg -tol*		$ang_tol]
	set res {}
	foreach tok [split $range ","] {
		set tok [string trim $tok]
		if {[regexp {^([xXyYzZ])\s*([><=]+)\s*(.+)} $tok dummy co op val]} {
			switch $op {
				">" {
					set min $val+$tol*(1.0+$eps)
					set max $_PI
				}
				"<" {
					set max $val-$tol*(1.0+$eps)
					set min 0
				}
				"<=" {
					set max $val
					set min 0
				}
				">=" {
					set min $val
					set max $_PI
				}
				"=" {
					set min $val
					set max $val
				} "==" {
					set min $val
					set max $val
				}
				default {
					 ::antool::utils::error  "Dont know this op! ($op)"
				}
			}
			lappend res $co
			lappend res $min
			lappend res $max
		} else {
			::antool::utils::error "what't the operator? $tok"
		}
	}
	return $res
}

proc antool::asel {args} {
	eval [concat antool::select $args -mode A]
}

proc antool::rsel {args} {
	eval [concat antool::select $args -mode R]
}

proc antool::usel {args} {
	eval [concat antool::select $args -mode U]
}

proc antool::sel {args} {
	eval [concat antool::select $args -mode S]
}

# usel,asel,rsel,ssel,allsel,nonesel,sel
proc antool::select {args} {
	variable coord_tol
	variable coord_big
	variable ang_tol
	variable _PI
	set coords 		[::antool::utils::unarg -coor* 	"none"		]
	set angle 		[::antool::utils::unarg -ang* 	"none"		]
	set neighbor 	[::antool::utils::unarg -neig* 	"none"		]
	set lines  		[::antool::utils::unflag -line*				]	;#a
	set all			[::antool::utils::unflag 	-all			]
	set none		[::antool::utils::unflag	-none			]
	set areas		[::antool::utils::unflag	-area*			]	;#a
	set kps			[::antool::utils::unflag	-kp*			]	;#a
	set nodes		[::antool::utils::unflag	-nod*			]	;#a
	set elem		[::antool::utils::unflag	-ele*			]	;#a
	set mode		[::antool::utils::unarg	-mode	"S"			]
	set csys		[::antool::utils::unarg	-csys	"none"		]
	set comp		[::antool::utils::unarg	-comp*	"none"		]	;#a
	set from		[::antool::utils::unarg	-from	"all"		]
	set list		[::antool::utils::unarg	-list*	"none"		]
	set allsel		[::antool::utils::unflag	-allsel*		]	;#a
	set nonesel		[::antool::utils::unflag	-nonesel*		]	;#a
	set volu		[::antool::utils::unflag	-vol*			]	;#a
	set q			[::antool::utils::unarg	-q*		"none"		]	;#a
	if {$csys ne "none"} {
		set oldcsys [ans_getvalue "ACTIVE,0,CSYS"]
		ans_sendcommand "CSYS,$csys"
	}
	######## LINE ##############
	if {$lines} {
		if {$coords ne "none"} {
			foreach {co min max} [antool::_parse_coord_ranges $coords] {
				ans_sendcommand "LSEL,$mode,LOC,$co,$min,$max"
			}
		} elseif {$angle ne "none"} {
			set list {}
			set nl [ans_getvalue "LINE,0,COUNT"]
			if {$nl == 0} {
			} else {
				set cn 0
				for {set i 0} {$i < $nl} {incr i} {
					set cn [ans_getvalue "LINE,$cn,NXTH"]
					foreach {co min max} [antool::_parse_angle_ranges $angle] {
						set sl [ans_evalexpr [format "LS%s($cn,0.5)" [string toupper $co]]]
						set angl [expr acos(abs($sl))/$_PI*180.0]
						#puts "Angle of line $cn : $angl"
						if {$angl >= [ans_evalexpr $min] && $angl <= [ans_evalexpr $max]} {
							lappend list $cn
							#puts "addit!"
						}
					}
				}
			}
			#ans_sendcommand "LSEL,NONE"
			comp -push L
				sel -line -none
				foreach li $list {
					ans_sendcommand "LSEL,A,,,$li"
				}
			set cna [comp -temp -lines]	
			comp -pop
			select -mode $mode -comp $cna
			comp -dele -name $cna	
		} elseif {$neighbor ne "none"} {
			ans_sendcommand "CM,_Y,KP"
			for {set i 0} {$i < $neighbor} {incr i} {
				puts "KSLL,S"
				ans_sendcommand "KSLL,S"
				puts "LSLK,A"
				ans_sendcommand "LSLK,A,0"
			}
			ans_sendcommand "CMSEL,S,_Y"
			ans_sendcommand "CMDELE,_Y"
		} elseif {$all} {
			ans_sendcommand "LSEL,ALL"
		} elseif {$none} {
			ans_sendcommand "LSEL,NONE"
		} elseif {$list ne "none"} {
			comp -push L
				ans_sendcommand "LSEL,NONE"
				foreach l $list {
					ans_sendcommand "LSEL,A,,,$l"
				}
			set cna [comp -temp -lines]	
			comp -pop
			select -mode $mode -comp $cna
			comp -dele -name $cna
		}
	######## AREA ##############
	} elseif {$areas} {
		if {$all} {
			ans_sendcommand "ASEL,ALL"
		} elseif {$none} {
			ans_sendcommand "ASEL,NONE"
		} elseif {$list ne "none"} {
			comp -push A
				apdl "ASEL,NONE"
				foreach l $list {
					apdl "ASEL,A,,,$l"
				}
			set cna [comp -temp -area]	
			comp -pop
			select -mode $mode -comp $cna
			comp -dele -name $cna
		}
	######## KP ##############
	} elseif {$kps} {
		if {$all} {
			ans_sendcommand "KSEL,ALL"
		} elseif {$none} {
			ans_sendcommand "KSEL,NONE"
		} elseif {$coords ne "none"} {
			comp -push K
			if {$from eq "all"} {
				ans_sendcommand "KSEL,ALL"
			} elseif {$from eq "cur"} {
				
			} else {
				sel -comp $from
			}
			foreach {co min max} [antool::_parse_coord_ranges $coords] {
				ans_sendcommand "KSEL,R,LOC,$co,$min,$max"
			}
			set cna [comp -temp -kp]
			comp -pop
			select -mode $mode -comp $cna
			comp -dele -name $cna
		}	elseif {$list ne "none"} {
			comp -push K
				ans_sendcommand "KSEL,NONE"
				foreach l $list {
					ans_sendcommand "KSEL,A,,,$l"
				}
			set cna [comp -temp -kps]	
			comp -pop
			select -mode $mode -comp $cna
			comp -dele -name $cna
		}
	######## NODE ##############
	} elseif {$nodes} {
		if {$all} {
			ans_sendcommand "NSEL,ALL"
		} elseif {$none} {
			ans_sendcommand "NSEL,NONE"
		} elseif {$coords ne "none"} {
			foreach {co min max} [antool::_parse_coord_ranges $coords] {
					puts "NSEL,$mode,LOC,$co,$min,$max"
					ans_sendcommand "NSEL,$mode,LOC,$co,$min,$max"
			}
		} elseif {$list ne "none"} {
			comp -push N
				ans_sendcommand "NSEL,NONE"
				foreach l $list {
					apdl "NSEL,A,,,$l"
				}
			set cna [comp -temp -node]	
			comp -pop
			select -mode $mode -comp $cna
			comp -dele -name $cna
		}
	######## COMP ##############
	} elseif {$comp ne "none"} {
		if {[llength $comp] > 1} {
			if {$mode ne "A"} {
				error "not now"
			} else {
				foreach co $comp {
					ans_sendcommand "CMSEL,A,'$co'"
				}
			}
		} else {
			ans_sendcommand "CMSEL,$mode,'$comp'"
		}
	######## ALLSEL ##############
	} elseif {$allsel} {
		sel -node -all
		sel -elem -all
		sel -kps -all
		sel -line -all
		sel -volu -all
	######## NONESEL ##############
	} elseif {$nonesel} {
		sel -node -none
		sel -elem -none
		sel -kps -none
		sel -line -none
		sel -volu -none
	######## VOLU ##############
	} elseif {$volu} {
		if {$all} {
			ans_sendcommand "VSEL,ALL"
		} elseif {$none} {
			ans_sendcommand "VSEL,NONE"
		} elseif {$list ne "none"} {
			comp -push V
				ans_sendcommand "VSEL,NONE"
				foreach l $list {
					apdl "VSEL,A,,,$l"
				}
			set cna [comp -temp -volu]	
			comp -pop
			select -mode $mode -comp $cna
			comp -dele -name $cna
		}
	######## ELEM ##############
	} elseif {$elem} {
		if {$all} {
			ans_sendcommand "ESEL,ALL"
		} elseif {$none} {
			ans_sendcommand "ESEL,NONE"
		} elseif {$list ne "none"} {
			comp -push E
				ans_sendcommand "ESEL,NONE"
				foreach l $list {
					apdl "ESEL,A,,,$l"
				}
			set cna [comp -temp -elem]	
			comp -pop
			select -mode $mode -comp $cna
			comp -dele -name $cna
		}
	} elseif {$q ne "none"} {
		comp -push NEKLAV
		_parse_entity $q -sel
		foreach na {node elem kp line area volu} {
			set cn$na [comp -temp -$na]
		}
		comp -pop
		foreach na {node elem kp line area volu} {
			select -mode $mode -comp [set cn$na]
			comp -dele -name [set cn$na]
		}
	}
	
	if {$csys ne "none"} {
		ans_sendcommand "CSYS,$oldcsys"
	}
}

proc antool::refine {args} {
	#refine -nodes -nearkp [list_selection -kp] -level 2 -depth 4 -post "OFF" -retain 1
	set nodes	[::antool::utils::unflag	-node*			]
	set nearkp	[::antool::utils::unarg	-nearkp*	"none"	]
	set level	[::antool::utils::unarg	-lev*		"1"	]
	set depth	[::antool::utils::unarg	-dep*		"1"	]
	set post	[::antool::utils::unarg	-post*		"OFF"	]
	set retain	[::antool::utils::unarg	-ret*		"1"	]
	if {$nodes} {
		if {$nearkp ne "none"} {
			foreach kp $nearkp {
				catch {ans_sendcommand "NREFINE,NODE(KX($kp),KY($kp),KZ($kp)), , ,$level,$depth,$post,$retain"}
			}
		} else {
			 ::antool::utils::error  "can't do it"
		}
	} else {
		 ::antool::utils::error  "Cant do it"
	}
}

proc antool::bcs {args} {
	set del	[::antool::utils::unarg	-del*	"none"	]
	if {$del eq "all"} {
		ans_sendcommand "LSCLEAR,ALL"
	}
}

proc antool::nres {args} {
	set ncomp	[::antool::utils::unarg 	-ncomp*	"none"	]
	set comp	[::antool::utils::unarg 	-comp*	"none"	]
	set rsys	[::antool::utils::unarg	-rs*	0	]
	if {$comp eq "none"} {
		 ::antool::utils::error  "What the component to collect?"
	}
	set oldrsys [ans_getvalue "ACTIVE,0,RSYS"]
	ans_sendcommand "RSYS,$rsys"
	set reslist {}
	if {$ncomp ne "none" && [comp -isname $ncomp -type 1]} {
		ans_sendcommand "CM,_Y,NODE"
		select -nodes -none
		comp -select -name $ncomp
		foreach n [list_selection -node] {
			lappend reslist [ans_getvalue "NODE,$n,$comp"]
		}
		ans_sendcommand "CMSEL,S,_Y"
		ans_sendcommand "CMDELE,_Y"
	}
	ans_sendcommand "RSYS,$oldrsys"
	return $reslist
}

proc antool::comp {args} {
	set actions 	{f add a isname f unsel a rename}
	set modifiers	{a name f area f line a type}
	set name	[::antool::utils::unarg		-name	"none"	]
	set add		[::antool::utils::unflag 	-add			] ;#
	set area	[::antool::utils::unflag 	-area*			]
	set line	[::antool::utils::unflag 	-line*			]
	set node	[::antool::utils::unflag	-node*			]
	set volu	[::antool::utils::unflag	-vol*			]
	set kps		[::antool::utils::unflag	-kp*			]
	set isname	[::antool::utils::unarg 	-isn*	"none"	] ;#
	set type	[::antool::utils::unarg 	-type*	0		] 
	set sel		[::antool::utils::unflag 	-sel*			] ;#
	set unsel	[::antool::utils::unarg 	-unsel*	"none"	] ;#
	set rename	[::antool::utils::unarg 	-rena*	"none"	] ;#
	set del		[::antool::utils::unflag 	-del*			] ;#
	set list	[::antool::utils::unflag	-list			]
	set push	[::antool::utils::unarg		-push	"none"	]
	set pop		[::antool::utils::unflag	-pop			]
	set find	[::antool::utils::unarg		-find	"none"	]
	set temp 	[::antool::utils::unflag	-temp			]
	set elem	[::antool::utils::unflag	-elem*			]
	variable _comp_stack_number
	variable _comp_stack_name
	array set comp {8 AREA 7 LINE 6 KP 2 ELEM 1 NODE 9 VOLU} ;#11-15 - subcomponents
	array set comp_inv {A 8 L 7 K 6 E 2 N 1 V 9}
	if {$area} {
		set type 8
	} elseif {$line} {
		set type 7
	} elseif {$node} {
		set type 1
	} elseif {$kps} {
		set type 6
	} elseif {$volu} {
		set type 9
	} elseif {$elem} {
		set type 2
	}
	if {$add} {
		if {[comp -isname $name -type $type]>0} {
			ans_sendcommand "CMSEL,A,'$name'"
			ans_sendcommand "CMDELE,'$name'"
		}
		ans_sendcommand "CM,$name,$comp($type)"
	} elseif {$isname ne "none"} {
		set nc [ans_getvalue "COMP,,NCOMP"]
		for {set i 1} {$i <= $nc} {incr i} {
			set na [string trim [ans_getvalue "COMP,$i,NAME"]]
			set ty [ans_getvalue "COMP,'$na',TYPE"]
			if {[string toupper $na] eq [string toupper $isname] && ($ty == $type || $type == 0)} {
				return $ty
			}
		}
		return 0
	} elseif {$find ne "none"} {
		set nc [ans_getvalue "COMP,,NCOMP"]
		set nlist {}
		for {set i 1} {$i <= $nc} {incr i} {
			set na [string trim [ans_getvalue "COMP,$i,NAME"]]
			if {[string match -nocase $find $na]} {
				lappend nlist $na
			}
		}
		return $nlist
	} elseif {$sel} {
		#puts "CMSEL,A,'$name'"
		ans_sendcommand "CMSEL,A,'$name'"
	} elseif {$unsel ne "none"} {
		ans_sendcommand "CMSEL,U,'$name'"
	} elseif {$rename ne "none"} {
		ans_sendcommand "CMMOD,'$name',NAME,$rename"
	} elseif {$del} {
		foreach na $name {
			ans_sendcommand "CMDELE,$na"
		}
	} elseif {$list} {
		set ty [comp -isname $name] 
		if {$ty} {
			switch $ty {
				1 {	set op -nodes }
				2 { set op -elem }
				default {
					::antool::utils::error "Dont know type $ty"
				}
			}
			ans_sendcommand "CM,_Y2,$comp($ty)"
			sel -comp $name
			set list [list_selection $op]
			ans_sendcommand "CMSEL,S,_Y2"
			ans_sendcommand "CMDELE,_Y2"
			return $list
		} else {
			::antool::utils::error "Can't find component $name"
		}
	} elseif {$pop} {
		if {$_comp_stack_number == 0} {
			::antool::utils::error "No components in stack! (_comp_stack_number = 0)"
		} 
		set names [comp -find ${_comp_stack_name}${_comp_stack_number}.*]
		asel -comp $names
		incr _comp_stack_number -1
	} elseif {$push ne "none"} {
		incr _comp_stack_number
		set push [string toupper $push]
		if {$push eq "ALL"} {
			set push NEKLAV
		}
		foreach t [split $push ""] {
			ans_sendcommand "CM,${_comp_stack_name}${_comp_stack_number}.$t,$comp($comp_inv($t))"
		}
	} elseif {$temp} {
		puts "in temp"
		set basename _Y
		for {set i 1} {1} {incr i} {
			if {![comp -isname $basename$i]} {
				if {$type} {
					puts "CM,$basename$i,$comp($type)"
					ans_sendcommand "CM,$basename$i,$comp($type)"
				}
				return $basename$i
			}
		}
	} else {
		 ::antool::utils::error  "comp: unknown action"
	}
}
proc antool::cad_import {args} {
	set file [::antool::utils::unarg -file*	"none"]
	set scale [::antool::utils::unflag -sca* ]
	set ent		[::antool::utils::unarg -ent* "SOLIDS"]
#Entity to be imported:
#SOLIDS — Solids only, imported as ANSYS volumes (default)
#SURFACES — Surfaces only, imported as ANSYS areas.
#WIREFRAME — Wireframe only, imported as ANSYS lines.
#ALL — All entities. Use this option when the file contains more than one type of entity.
	if {$file eq "none"} {
		 ::antool::utils::error  "need file to import"
	}
	foreach fi $file {
		if {[file extension $fi] eq ".x_t"} {
			catch {ans_sendcommand "~PARAIN,'[file root [file tail $fi]]','[string range [file extension $fi] 1 end]',[file dirname $fi],$ent,0,$scale"}
		} elseif {[file extension $fi] eq ".sat"} {
			catch {ans_sendcommand "~SATIN,'[file root [file tail $fi]]','[string range [file extension $fi] 1 end]',[file dirname $fi],$ent,0"}
		} elseif {[file extension $fi] eq ".IGS"} {
			ans_sendcommand "/AUX15"
			ans_sendcommand "IOPTN,IGES,SMOOTH "
			ans_sendcommand "IOPTN,MERGE,YES "
			ans_sendcommand "IOPTN,SOLID,YES "
			ans_sendcommand "IOPTN,SMALL,NO  "
			ans_sendcommand "IOPTN,GTOLER, DEFA"  
			catch {ans_sendcommand "IGESIN,'[file root [file tail $fi]]','[string range [file extension $fi] 1 end]','[file dirname $fi]'  "}
			ans_sendcommand "FINISH"
		} 
	}

}

proc antool::_flst {args} {
	set list 	[::antool::utils::unarg	-lis*	"none"	]
	set lines 	[::antool::utils::unflag	-lin*		]
	set kps		[::antool::utils::unflag	-kp*		]
	set areas	[::antool::utils::unflag	-ar*		]
	set pos		[::antool::utils::unarg	-pos*	"5"	]
	set orde	[::antool::utils::unarg	-orde*	""	]
	
	set list [_unroll_list $list]
	set nl [llength $list]
	set type {}
	if {$lines} {
		set type 4
	} elseif {$areas} {
		error why?
		set type {} ;# dont know now
	} elseif {$kps} {
		set type 3
	} else {
		 ::antool::utils::error  "You must choose type of list"
	}
	ans_sendcommand "FLST,$pos,$nl,$type,$orde"
	foreach l $list {
		ans_sendcommand "FITEM,$pos,$l"
	}
}

proc antool::_unroll_list {list} {
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

proc antool::_get_index_by_colorname {cmap cname {what name}} {
	upvar $cmap map
	foreach n [array names map -glob "*,$what"] {
		if {$map($n) eq $cname} {
			set ind [lindex [split $n ,] 0]
			return $ind
		}
	}
	return -1 ;#dont find :(
}

proc antool::_get_index_by_rgb {cmap rgb {what rgb}} {
	upvar $cmap map
	foreach n [array names map -glob "*,$what"] {
		if {$map($n) eq $rgb} {
			set ind [lindex [split $n ,] 0]
			return $ind
		}
	}
	return -1 ;#dont find :(
}

proc antool::ce {args} {
	set rigid	[::antool::utils::unflag	-rig*			]
	set	master	[::antool::utils::unarg	-mast*	"none"	]
	set slave	[::antool::utils::unarg	-sl*	"none"	]
	set dofs	[::antool::utils::unarg	-dof*	"ALL"	]
	set rbe3	[::antool::utils::unflag	-rbe3*			]
	if {$rigid} {
		if {$master ne "none" && $slave ne "none"} {
			set ma [comp -list -name $master]
			if {[llength $ma] != 1} {
				::antool::utils::error "Master node must be 1! (got [llength $ma])"
			}
			ans_sendcommand "CM,_Y,NODE"
			sel -comp $slave
			asel -comp $master
			puts "CERIG,$ma,ALL,$dofs"
			ans_sendcommand "CERIG,$ma,ALL,$dofs"
			ans_sendcommand "CMSEL,S,_Y"
			ans_sendcommand "CMDELE,_Y"
		}
	} elseif {$rbe3} {
		if {$master ne "none" && $slave ne "none"} {
			set ma [comp -list -name $master]
			if {[llength $ma] != 1} {
				::antool::utils::error "Master node must be 1! (got [llength $ma])"
			}
			comp -push N
			sel -comp $slave
			asel -comp $master
			ans_sendcommand "RBE3,$ma,$dofs,ALL,"
			comp -pop
		}
	}
}

proc antool::angular_unit {args} {
	ans_sendcommand "*AFUN,$args"
}

proc antool::area {args} {
	set rot		[::antool::utils::unarg	-rot*	"none"	]
	set lines	[::antool::utils::unarg	-lin*	"none"	]
	set axis	[::antool::utils::unarg	-ax*	"none"	]
	set vec		[::antool::utils::unarg	-vec*	"none"	]
	if {$rot ne "none"} {
		comp -push "KLA"
		set lin [_parse_entity $lines -enum line]
		#sel -line -list $lines
		set ax	[_parse_entity $axis -enum kp]
		asel -q "$lines"
		asel -q "$axis"
		#sel -kps -list $axis
		sel -area -none
		ans_sendcommand "KSLL,A"
		_flst -pos 2 -lines -list $lin
		_flst -pos 8 -kps -list $ax
		ans_sendcommand "AROTAT,P51X, , , , , ,P51X, ,$rot"
		set ar [::antool::list::selection -type A]
		#set ar [list_selection -area]
		comp -pop
		#todo: sel new area
		return $ar
	}
	if {$vec ne "none"} {
		#ADRAG,      94, , , , , ,      14 
		comp -push "ALK"
		#sel -lines -list $lines
		_parse_entity $lines -sel
		sel -area -none
		set cna [comp -temp -lines]
		apdl "KSLL,S"
		set kp [lindex [list_selection -kps] 0]
		set kx [ans_evalexpr "KX($kp)"]
		set ky [ans_evalexpr "KY($kp)"]
		set kz [ans_evalexpr "KZ($kp)"]
		foreach {vx vy vz} $vec {break}
		sel -kps -none
		apdl "K,,$kx,$ky,$kz"
		apdl "K,,$kx+\($vx\),$ky+\($vy\),$kz+\($vz\)"
		
		set myline [::antool::list::enumerate -list [line -bykp "sel.kp"] -type line]
		apdl "ADRAG,$cna,,,,,,$myline"
		apdl "LDELE,$myline,,,1"
		comp -name $cna -dele 
		set ar [::antool::list::selection -type A]
		comp -pop
		return $ar
	}
}

proc antool::msg {args} {
	set string	[::antool::utils::unarg	-str*	"default message"	]
	set format	[::antool::utils::unarg	-for*	"%C"				]
	set	lvl		[::antool::utils::unarg	-lev*	"INFO"				]
	
	#todo: make more safe (caution of overwriting)
	set fname "antool_file_for_msg_command.apdl"
	set f [open $fname "w"]
	puts $f "*MSG,$lvl,'$string'"
	puts $f "$format"
	puts $f ""
	close $f
	catch {ans_sendcommand "/INPUT,[file rootname $fname],[string range [file extension $fname] 1 end]"}
	file delete -force $fname
}

proc antool::line {args} {	
	if {[::antool::utils::unarg2 arg bykp -bykp*	]} {
		::antool::utils::isargs
		comp -push "LK"
			#sel -kps -all
			sel -lines -none
			foreach {a b} [_parse_entity $bykp -enum kp -sel] {
				apdl "LSTR,$a,$b" -nowarning
			}
			set lst [::antool::list::selection -type L]
		comp -pop
		return $lst
	}
}

proc ::antool::_parse_entity {q args} {
	set enum	[::antool::utils::unarg		-enum*		"none"	]
	set sel		[::antool::utils::unflag	-sel*				]
	set list	[::antool::utils::unflag	-list*				]

	switch -exact [::antool::_entity_auto_detect q] $::antool::query::query_hint {
			if {$sel && $enum ne "none"} {
				return [::antool::list::enumerate -list [::antool::query::do $q -sel -list] -type $enum]
			} elseif {$sel && $list} {
				return [::antool::query::do $q -list -sel]
			} elseif {$sel} {
				::antool::query::do $q -sel
				return
			} elseif {$enum ne "none"} {
				return [::antool::list::enumerate -list [::antool::query::do $q -list] -type $enum]
			} elseif {$list} {
				return [::antool::query::do $q -list]
			} else {
				::antool::utils::error "don't know what to do (nature = $nature)"
			}	
		}	$::antool::list::list_hint {
			if {$sel} {
				foreach {fu sh} $::antool::list::types_list {
					set mlist [::antool::list::enumerate -list $q -type $fu]
					if {$mlist == {}} {
						sel -$fu -none
					} else {
						::antool::sel -$fu -list $mlist
					}
				}
				if {$list} {
					return $q
				} elseif {$enum ne "none"} {
					return [::antool::list::enumerate -list $q -type $enum]
				}
				return
			} elseif {$enum ne "none"} {
				return [::antool::list::enumerate -list $q -type $enum]
			} elseif {$list} {
				return $q
			} else {
				::antool::utils::error "don't know what to do (nature = $nature)"
			}
		}
		default {
			::antool::utils::error "Why I am here? :("
		}
}

proc ::antool::_entity_auto_detect {_q args} {
	#set q [string toupper $q]
	upvar 1 $_q q
	if {[regexp "^\\s*($::antool::list::list_hint\\s+|)(\[[join $::antool::list::types_shortlist ""]\]\\s+\\d+.*)" $q dummy hint other]} {
		if {$hint == {}} {
				set q "$::antool::list::list_hint $q"
		}
		set q $other
		return $::antool::list::list_hint
	} else {
		if {[regexp "^\\s*($::antool::query::query_hint\\s+|)(.*)" $q dummy hint other]} {
			set q $other
		}
		return $::antool::query::query_hint
	}
}


proc ::antool::real {args} {
	if {[::antool::utils::unarg2	flag	max -max*	0]} {
		return [ans_getvalue "RCON,,NUM,MAX"]
	}
	::antool::utils::isargs
}

proc ::antool::type {args} {
	if {[::antool::utils::unarg2	flag	max -max*	0]} {
		return [ans_getvalue "ETYP,,NUM,MAX"]
	}
	::antool::utils::isargs
}

proc ::antool::contact {args} {
	::antool::utils::unarg2 arg 	target	-tar*	
	::antool::utils::unarg2 arg 	contact	-con*
	::antool::utils::unarg2 flag	bonded	-bon*	0
	::antool::utils::unarg2 flag	trim	-trim*	0
	
	if {[info exists bonded]} {
		comp -push NEKLAV
		sel -selnone
		ans_sendcommand "MP,MU,1,"
		ans_sendcommand "MP,EMIS,1,7.88860905221e-031"
		set real [expr [real -max]+1]
		set tartype [expr [type -max]+1]
		set contype [expr [type -max]+2]
		ans_sendcommand "R,$real,,,1.0,0.1,0,"
		ans_sendcommand "RMORE,,,1.0E20,0.0,1.0, "
		ans_sendcommand "RMORE,0.0,0,1.0,,1.0,0.5"
		ans_sendcommand "RMORE,0,1.0,1.0,0.0,,1.0"
		ans_sendcommand "RMORE,10.0 "
		ans_sendcommand "ET,$tartype,170"
		ans_sendcommand "KEYOPT,$tartype,5,0"
		ans_sendcommand "ET,$contype,175"
		ans_sendcommand "KEYOPT,$contype,4,0"
		ans_sendcommand "KEYOPT,$contype,5,0"
		ans_sendcommand "KEYOPT,$contype,7,0"
		ans_sendcommand "KEYOPT,$contype,8,0"
		ans_sendcommand "KEYOPT,$contype,9,0"
		ans_sendcommand "KEYOPT,$contype,10,2  " 
		ans_sendcommand "KEYOPT,$contype,11,0 "  
		ans_sendcommand "KEYOPT,$contype,12,5"   
		ans_sendcommand "KEYOPT,$contype,2,0"
		#target
		::antool::_parse_entity $target -sel
		ans_sendcommand "TYPE,$tartype"
		ans_sendcommand "ESLN,S,0"
		ans_sendcommand "ESLL,U  "
		ans_sendcommand "ESEL,U,ENAME,,188,189   "
		ans_sendcommand "NSLE,A,CT2  "
		ans_sendcommand "ESURF"
		ans_sendcommand "ESEL,R,TYPE,,$tartype"
		comp -add -name "CNT_R$real" -elem
		#contact
		::antool::_parse_entity $contact -sel
		ans_sendcommand "TYPE,$contype"  
		ans_sendcommand "ESLN,S,0"
		ans_sendcommand "NSLE,A,CT2" 
		ans_sendcommand "ESURF "
		ans_sendcommand "ESEL,R,TYPE,,$contype"
		comp -add -name CNT_R$real -elem
		if {$trim} {
			asel -comp CNT_R$real
			apdl "CNCHECK,TRIM,,,,ANY,AGGRE" -nowarning
		}
		comp -pop
		asel -comp CNT_R$real
		
	} else {
		::antool::utils::error "It doesn't work now (only -bonded_"
	}
}


proc ::antool::tol {args} {
	variable coord_tol
	if {[::antool::utils::unarg2 arg 	cs	-coord_set* {}]} {
		apdl "SELTOL, $cs"
		set coord_tol $cs
	} elseif {[::antool::utils::unarg2 flag 	cg	-coord_get*]} {
		return $coord_tol
	}
}


namespace import -force antool::\[a-zA-z\]* 
puts "****************************************************"
puts "*  library ANTool v$::antool::version loaded!                     *"
puts "*  All rights belong to Dmitry Khominich.          *"
puts "*  It's free to use ANTool in non-commercial way.  *"
puts "*  For commercial use please contact the developer.*"
puts "*  Contact mail KhDmitryi@gmail.com                *"
puts "****************************************************"