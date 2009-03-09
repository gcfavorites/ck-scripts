encoding system utf-8
::ck::require cmd

namespace eval ::idle {
    variable version 0.1
    variable originalauthor "Stream"
    variable author "kns@RusNet"


    namespace import -force ::ck::cmd::*
}

proc ::idle::init {  } {

    cmd register idle [namespace current]::run -doc "idle" \
        -bind "idle" -bind "идл"

    cmd doc "idle" {~*!idle* [nick]~ - топ молчунов или время которое [nick] спал на канале.}

    msgreg {
        botnick     сплю я, сплю... Разбудишь - я не виноват.
        itself      амнезия?
        toosmall    %s только что говорил.
        norm        %s молчит уже %s.
        absent      я не вижу здесь %s...
        max.nick    дольше всех молчишь ты, ни слова уже %s.
        max.norm    дольше всех молчит %s, ни слова уже %s.
        max.none    подозрительно всё это... никто не молчит.
    }
}


proc ::idle::run { sid } {
    session import

    if { $Event eq "CmdPass" } {

        set unick [lindex $StdArgs 1]

        if {$unick ne ""} {
            if {[onchan $unick $Channel]} {
                if {[string equal -nocase $::botnick $unick]} {
                    reply botnick
                } elseif {[string equal -nocase $Nick $unick]} {
                    reply itself
                } else {
                    set idletime [getchanidle $unick $Channel]
                    if {[expr {$idletime < 1}]} {
                        reply toosmall $unick
                    } else {
                        reply norm $unick [duration $idletime]
                    }
                    unset idletime
                }
            } else {
                reply absent $unick
            }
            unset unick
        } else {
            set maxidle 0
            set maxidlenick ""
            foreach unick [chanlist $Channel] {
                if {[isbotnick $unick]} {continue}
                set idletime [getchanidle $unick $Channel]
                if {[expr {$idletime > $maxidle}]} {
                    set maxidle $idletime
                    set maxidlenick $unick
                }
            }

            if {$maxidle} {
                if {$maxidlenick eq $Nick} {
                    reply max.nick [::idle::duration $maxidle]
                } else {
                    reply max.norm $maxidlenick [::idle::duration $maxidle]
                }
            } else {
                reply max.none
            }
            unset maxidle maxidlenick unick
        }
    }

    return
}

proc ::idle::duration {minutes} {
    set years [expr {$minutes / 524160}]
    set minutes [expr {$minutes % 524160}]
    set weeks [expr {$minutes / 10080}]
    set minutes [expr {$minutes % 10080}]
    set days [expr {$minutes / 1440}]
    set minutes [expr {$minutes % 1440}]
    set hours [expr {$minutes / 60}]
    set minutes [expr {$minutes % 60}]
    set res ""
    if {$years != 0} {lappend res [numstr $years "год" "года" "лет"]}
    if {$weeks != 0} {lappend res [numstr $weeks "неделю" "недели" "недель"]}
    if {$days != 0} {lappend res [numstr $days "день" "дня" "дней"]}
    if {$hours != 0} {lappend res [numstr $hours "час" "часа" "часов"]}
    if {$minutes != 0} {lappend res [numstr $minutes "минуту" "минуты" "минут"]}


    unset years weeks days hours minutes

    return [join $res ", "]
}

proc ::idle::numstr {val str1 str2 str3} {

    switch -glob -- $val {
        *11         -
        *12         -
        *13         -
        *14     {set d1 2}
        *1      {set d1 0}
        *2          -
        *3          -
        *4      {set d1 1}
        default {set d1 2}
    }

    set d2 [lindex [list $str1 $str2 $str3] $d1]

    set ret "$val $d2"

    unset d1 d2 val str1 str2 str3

    return $ret
}

::idle::init