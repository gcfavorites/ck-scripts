encoding system utf-8
::ck::require cmd
::ck::require strings

namespace eval ::sbotuptime {
    variable version 0.1
    variable author "kns@RusNet"


    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::strings::html

}

proc ::sbotuptime::init {  } {

    cmd register sbotuptime [namespace current]::run -doc "sbotuptime" \
        -bind "memory" -bind "uptime"

    cmd register sbotuptime0 [namespace current]::run -doc "sbotuptime.suptime" \
        -bind "suptime" -config "sbotuptime"

    config register -id "access" -type str -default "m|-" \
        -desc "Флаг доступа." -access "n" -folder "sbotuptime"

    cmd doc -link "sbotuptime.suptime" "sbotuptime" \
        {~*!memory*~ - информация об аптайме бота и кол-ве памяти, занятой им.}

    cmd doc -link "sbotuptime" "sbotuptime.suptime" \
        {~*!suptime*~ - аптайм шелла.}

    msgreg {
        mem         My uptime: %s. And I use %s of %s kB memory (%s%%).
        supt        Uptime of my shell: %s (%s day(s)).
    }
}


proc ::sbotuptime::run { sid } {
    session import

    if { $Event eq "CmdPass" } {

        session set CmdAccess [config get "access"]
        
        if {[string match -nocase {*[a-z]*} $CmdAccess]} {
            checkaccess -return
        }

        if {$CmdId eq "sbotuptime0"} {
            set upt [expr round([lindex [split [exec cat /proc/uptime]] 0])]
            reply -noperson supt [duration $upt] [expr {$upt / 3600 / 24}]

            unset upt

            return
        }

        set mem [string trim [exec ps -orss= -p [exec cat $::pidfile]]]
        regexp -- {^MemTotal:\s+(\d+)\s} [exec cat /proc/meminfo] -> memtotal

        set r [format %.2f [expr {double($mem) / $memtotal * 100}]]
        set u [duration [expr {[clock seconds] - $::uptime}]]

        reply -noperson mem $u $mem $memtotal $r

        unset r u mem -> memtotal
    }

    return
}

::sbotuptime::init