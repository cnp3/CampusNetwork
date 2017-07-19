# NOT USED ANYMORE #

You need to install this:

    sudo apt-get install ntop

It launch a custom installation:

    For the fisrt window, do esc.
    For the next, enter the password 'admin'.
    For the last, enter again the password 'admin'.


For now, ntop run only on node HALL.
This run on port 3000 with http. (/!\ firewall)
To test it, run for example:

    sudo util/exec_command.sh HALL curl http://[::1]:3000 > output.html

Then, open output.html with a browser to see the result.
