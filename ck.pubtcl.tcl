encoding system utf-8
::ck::require cmd

namespace eval ::pubtcl {
    variable version 0.2
    variable author "kns@RusNet"


    namespace import -force ::ck::cmd::*
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

if {[lsearch [info procs ::*time*] ::time] != -1} {
    proc ::pubtcl::time {str} {
        set sSsSsSs [clock clicks]
        uplevel $str
        set dDdDdDd [clock clicks]

        if {[info exists sSsSsSs] && [info exists dDdDdDd] \
                && ![array exists sSsSsSs] && ![array exists dDdDdDd] \
                && [string is integer $sSsSsSs] && [string is integer $dDdDdDd]} {
            return [expr $dDdDdDd-$sSsSsSs]
        } else {return 0}
    }
}


proc ::pubtcl::run { sid } {
    session import

    if { $Event eq "CmdPass" } {

        session set CmdAccess [config get "access.add"]
        checkaccess -return

        set ustr [join [lrange $StdArgs 1 end]]
        set RetTime [time {set RetCode [catch {eval $ustr} Result]}]
        set RetTime [expr {[lindex [split $RetTime] 0] / 1000.0}]
        unset ustr

        if {$Result eq ""} { set Result "<no error>" }

        set Result [split $Result \n]
        set ResLen [llength $Result]
        set RetCode [conv $RetCode]

        set MaxLines [expr {[config get "maxlines"] + 1}]
        set PrivLines [expr {[config get "privlines"] + 1}]

        session set CmdReplyParam [list "-noperson"]

        if {$ResLen eq 1} {
#            всего одна строчка
            session set CmdReplyParam [list "-multi"]
            reply rtd [join $Result] $RetCode $RetTime
            return
        } elseif {$ResLen > $MaxLines} {
#            слишком много строк на выходе. позже приделаю -force
            reply big $ResLen
            return
        } elseif {($ResLen >= $PrivLines) && ($ResLen <= $MaxLines)} {
#            выводим в приват
            session set CmdEvent "msg"
        }

        if {$CmdId eq "pubtcltim"} {
#            добавляем строчку с информацией
            lappend Result [cformat rt $RetCode $RetTime]
        }

        set bLine ""
        foreach_ $Result {
            if {![string is space $_] && ($_ ne $bLine)} {
                reply $_
                set bLine $_
            }
        }
    }

    return
}

proc ::pubtcl::conv { num } {
    return [lindex {OK ERROR RETURN BREAK CONTINUE} $num]
}

::pubtcl::init
