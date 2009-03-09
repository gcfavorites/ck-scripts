encoding system utf-8
::ck::require cmd
::ck::require strings

namespace eval ::pubtcl {
    variable version 0.1
    variable author "kns@RusNet"


    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::strings::html

}

proc ::pubtcl::init {  } {

    cmd register pubtcl [namespace current]::run -doc "pubtcl" -autousage \
        -bind {$$} -access "n"

    cmd register pubtcltim [namespace current]::run -doc "pubtcl" -autousage \
        -bind {$$$} -access "n" -config "pubtcl"

    cmd doc "pubtcl" {~*$$* <smth>~ - выполнение указанных команд.}

    config register -id "access.add" -type str -default "T|-" \
        -desc "Дополнительный флаг доступа" -access "n" -folder "pubtcl"

    config register -id "maxlines" -type int -default 15 \
        -desc "Максимальное кол-во выводимых линий" -access "n" -folder "pubtcl"

    config register -id "privlines" -type int -default 5 \
        -desc "Максимальное кол-во линий, выводимых на канал" -access "n" -folder "pubtcl"

    msgreg {
        big     Answer is very big (%s lines). Stopping.
        rtd     %s &n(%s :: %s ms)
        rt      -> %s :: %s ms <-
    }
}


proc ::pubtcl::run { sid } {
    session import

    if { $Event eq "CmdPass" } {

        session set CmdAccess [config get "access.add"]
        checkaccess -return

        set stim [expr {$CmdId eq "pubtcltim"}]

        set ustr [join [lrange $StdArgs 1 end]]

        set tim [time {set ret [catch {eval $ustr} result]}]
        set tim [expr {[lindex [split $tim] 0] / 1000.0}]

        if {$result eq ""} {
            reply "<no error>"
        } else {
            set tmp [split $result \n]
            set ltmp [llength $tmp]

            set maxlines [config get "maxlines"]
            set privlines [config get "privlines"]

            if {[expr {$ltmp > ($maxlines + 1)}]} {
                reply big $ltmp
                set tmp [list]
                set stim 0
            } elseif {[expr {$ltmp > ($privlines + 1)}]} {
                session set CmdReplyParam [list "-noperson" "-private"]
                session set CmdEvent "msg"
            } elseif {[expr {$ltmp == 1}]} {
                set tmp [lreplace $tmp 0 0 [cformat rtd $result [conv $ret] $tim]]
                set stim 0
            } else {
                session set CmdReplyParam [list "-noperson"]
            }

            set ssline ""
            foreach sline $tmp {
                if {([string length [string trim $sline]] > 0) \
                        && ($sline ne $ssline)} {
                    reply $sline
                    set ssline $sline
                }
            }

            if {$stim} {
                reply [cformat rt $ret $tim]
            }

            unset tmp ltmp result ssline stim maxlines privlines
        }

        unset ret tim ustr
    }

    return
}

proc ::pubtcl::conv { num } {
    switch -exact -- $num {
        0 {set e "OK"}
        1 {set e "ERROR"}
        2 {set e "RETURN"}
        3 {set e "BREAK"}
        4 {set e "CONTINUE"}
        default {set e "OK"}
    }
    return $e
}

::pubtcl::init