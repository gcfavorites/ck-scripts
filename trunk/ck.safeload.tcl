encoding system utf-8
::ck::require cmd
::ck::require strings

namespace eval ::safeload {
    variable version 0.1
    variable author "kns@RusNet"


    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::strings::html

}

proc ::safeload::init {  } {

    cmd register safeload [namespace current]::run -doc "safeload" -autousage \
        -force-prefix -bind "load" -access "n"

    cmd doc "safeload" {~*!load* <script> [dir]~ - подгрузка tcl-скрипта.}

    msgreg {
        ram       Скрипт:&B %s &K::&n Размер:&B %s &K::&n Изменение оперативки:&B %s&n.
        noram     Скрипт:&B %s &K::&n Размер:&B %s&n.
        okrepl    -&gOk&n- %s
        errrepl   -&RError&n- %s
    }
}


proc ::safeload::run { sid } {
    session import

    if { $Event eq "CmdPass" } {


        set script [lindex $StdArgs 1]
        set dir [lindex $StdArgs 2]

        if {$dir eq ""} {set dir "-"} {set dir [list $dir]}

        set ram1 [string trim [exec ps -orss= -p [exec cat $::pidfile]]]
        set res [::ck::source $script $dir]
        set ram2 [string trim [exec ps -orss= -p [exec cat $::pidfile]]]

        if {$res eq "-"} {
            set repl "Ошибка при загрузке скрипта"
            set res "errrepl"
        } elseif {$res eq ""} {
            set repl "Этот скрипт уже загружен"
            set res "okrepl"
        } else {
            set size [file size $res]
            set size [format %.3f [expr {$size / 1024.0}]]
            set ram [expr {$ram2 - $ram1}]
            if {$ram} {
                set repl [cformat ram $script $size $ram]
            } else {
                set repl [cformat noram $script $size]
            }

            set res "okrepl"

            unset size ram
        }

        reply -noperson $res $repl

        unset ram1 ram2 res script dir repl
    }

    return
}

::safeload::init