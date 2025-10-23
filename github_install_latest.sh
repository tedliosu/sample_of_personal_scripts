#!/bin/bash

set -euo pipefail

# For any system running the debian package manager "dpkg",
#     this script downloads the latest debian package of
#     a piece of software from GitHub and installs the package
#     using "dpkg" on the user's local machine.
#
# NOTE: this script MUST use Bash as its shell interpreter
#       because other shells such as Dash or OpenBSD ksh
#       do NOT have a "UID" environment variable which
#       stores the user id of the current user running
#       this script.

# Exit codes used by this script
EXIT_SUCCESS="$(set -e; "$(set -e; which true)" && echo "$?")"
EXIT_FAILURE="$(set -e; "$(set -e; which false)" || echo "$?")"

readonly MAX_ARGS=3
# Taken care of by set -e
#shellcheck disable=SC2155
readonly PROGS_METADATA_FILE="$(set -e; dirname "$0")/install_latest_script_data/packages_info.json"
readonly JQN_CMD="jq.node --no-color"

if [ "$#" -le 0 ]; then
    echo "Usage: $0 [--package PACKAGE_NAME] [--verbose]"
    exit "$EXIT_SUCCESS"
fi

num_args_processed=0
package_name=""

while [ "$#" -gt 0 ] && [ "$num_args_processed" -lt "$MAX_ARGS" ]; do
    case "$1" in
        # If the "--verbose" flag was passed onto this script, then
        #     have this script display all the gory details of each
        #     command being executed.
        --verbose)
            set -x
            shift
            ((++num_args_processed))
            ;;
        --package)
            if [ -z "${2-}" ]; then
                echo "Missing package name!" >&2
                exit "$EXIT_FAILURE"
            fi
            if ! eval "$(set -e; <"$PROGS_METADATA_FILE" $JQN_CMD "some({name:\"${2}\"})")"; then
                echo "Package metadata not present in $PROGS_METADATA_FILE!"
                exit "$EXIT_FAILURE"
            fi
            package_name="$2"
            shift 2
            ((num_args_processed+=2))
            ;;
        *)
            echo "Usage: $0 [--package PACKAGE_NAME] [--verbose]"
            exit "$EXIT_FAILURE"
            ;;
    esac
done

# We want this variable to be readonly and the `set -e` at the beginning will take care of any unsuccesful
#     command executions within the substituted command.
#shellcheck disable=SC2155
readonly package_metadata="$(set -e; <"$PROGS_METADATA_FILE" $JQN_CMD "filter({name:\"${package_name}\"})")"

# Prevent this script from being run as root,
#     since this script uses a regular user's
#     "/run/user/[insert user id here]" directory
#     to cache the downloaded debian package
#     of the program.
if [ "$UID" -eq 0 ]; then
   echo -e "\nDon't run $0 as root!\n" >&2
   exit "$EXIT_FAILURE"
fi

# The following function sets up the global
#     variables and temporary directory used
#     by the rest of this script EXCEPT
#     for everything relating to inter-process
#     signal handling, exit codes, handling 
#     script parameters, and handling environment
#     variables.
function setup_variables_and_directory() {

    # The url of the GitHub webpage hosting a structured JSON document storing details
    #     of all of the downloadable assets of the latest version of the program to be
    #     installed, with the details also including which GitHub url to use to directly
    #     download the latest debian package. This script will cache the document to
    #     efficiently parse the document for the url from which to download the debian package.
    #     SC2155 is taken care of by the set -e
    #shellcheck disable=SC2155
    readonly REPO_QUERY_URL="$(set -e; echo "$package_metadata" | $JQN_CMD "map(\"query_url\") | head")"
    #shellcheck disable=SC2155
    readonly DEB_REGEX="$(set -e; echo "$package_metadata" | $JQN_CMD "map(\"deb_regex\") | head")"
    # Following if...else block of code configures options to be passed
    #     onto commands executed later by this script. The code in the
    #     "if" part of the block is for configuring the options for the
    #     commands to have verbose output IF the user wishes this script
    #     to verbosely output each step of what the script is doing...
    if echo "$-" | grep --extended-regexp --quiet ".*x.*"; then
       CURL_NON_OUTPUT_OPTS="--verbose --fail-early --location"
       CURL_QUERY_ONLY_OPTS="$CURL_NON_OUTPUT_OPTS"
       REMOVE_OPTS="--verbose --recursive --force"
    # Otherwise, don't have the commands used by this script
    #      print verbose output.  For the "curl" command/program
    #      this means passing options such as "--progress-bar" and
    #      "--silent" to the command so that "curl" either only
    #      outputs a progress bar showing the download progress
    #      OR outputs absolutely nothing at all to stdout.
    else
       CURL_NON_OUTPUT_OPTS="--progress-bar --fail-early --location"
       CURL_QUERY_ONLY_OPTS="--silent --show-error --fail-early --location"
       REMOVE_OPTS="--recursive --force"
    fi
    # Store the "sudo" command along with the option(s) to be
    #     passed onto the command. "sudo" is used to obtain superuser
    #     privileges to install the debian package from GitHub.
    readonly SUDO_COMMAND="sudo --set-home"
    # Next variable is the name of the file which is the
    #     cached JSON document fetched from GitHub. The
    #     document is cached so that this script may
    #     efficiently parse the document for getting
    #     the url from which to download the debian package.
    readonly GITHUB_API_JSON_MAIN="releases_index.json"
    # Following four variables store JSON parsing commands to be executed
    #     by "jq.node" to parse the JSON document fetched from GitHub.
    readonly JQN_CHECK_ASSETS_SIZE="property(\"assets\") | keys | size"
    readonly JQN_CHECK_DOWNLOAD_URLS="property(\"assets\") | every(\"browser_download_url\")"
    readonly PRERELEASE_VAL_JQN_FILTER="property(\"prerelease\")"
    readonly JQN_GET_URLS_N_DIGESTS="property(\"assets\") | map(pick([\"digest\", \"browser_download_url\"]))"
    # Flag variable indicating whether or not the user has installed the package.
    USER_INSTALLED="no"
    # Temporary working directory to switch to for caching GitHub downloads.
    TEMP_WORKING_DIR="$(set -e; mktemp --directory --tmpdir="/run/user/$(set -e; id -u)/" "sh-$$.XXXXXXXXXX")"
    # Notify user we've created temporary directory to store GitHub downloads.
    echo -e "\nCreated temporary directory \"$TEMP_WORKING_DIR\" to store"
    echo "    downloads from GitHub..."
    # Initial working directory from where this script was called;
    #     this script will revert back to the initial working directory
    #     before exiting.
    PRE_SCRIPT_RUN_PWD="$PWD"

}

function validate_package() {

    REPO_BROWSER_URL="$(set -e; echo "$3" | \
                            awk --field-separator "/" "{print \"https://github.com/\" \$5 \"/\" \$6}")"

    if ! echo "$2  $1" | sha256sum --check - | grep --quiet "OK"; then
        echo -e "\033[1m" >&2
        echo "ERROR! hash digest from GitHub API and actual file checksum DON'T match!" >&2
        echo -e "\033[0m" >&2
        exit "$EXIT_FAILURE"
    else
        echo -e "\033[1m"
        echo "checksum check passed, but installed package authenticity NOT guaranteed!"
        echo "for updates and security notices, consider watching the repo:"
        echo "  $REPO_BROWSER_URL"
        echo -e "\033[0m"
    fi

}

# Main function responsible for downloading the correct latest
#     debian package from GitHub and then installing the package
#     as a system wide package on the user's machine.
function main() {
    
    # Change working directory of this script to directory used 
    #     to cache downloads from GitHub.
    cd "$TEMP_WORKING_DIR"
    # Notifying user what we're querying.
    echo -ne "\nQuerying latest debian package of $package_name..."
    # Download the JSON document from GitHub containing urls of all of the downloadable
    #     assets of the latest software version.
    # Splitting and globbing intentional here
    #shellcheck disable=SC2086
    curl $CURL_QUERY_ONLY_OPTS "$REPO_QUERY_URL" >"$GITHUB_API_JSON_MAIN"

    # If the JSON document downloaded from GitHub doesn't contain any entries
    #     on downloadable assets, OR if a download url is missing for at least one
    #     of the downloadable assets listed, then exit this script with an error
    #     telling the user that the debian package is inaccessible through GitHub.
    #     While it is true that having at least one of the assets missing a download
    #     url may not always imply that the url to the debian package is missing, I
    #     am simply playing it safe here by deciding that the integrity of the JSON
    #     document downloaded from GitHub is guaranteed IF AND ONLY IF each asset
    #     listing has a download url present.
    if [ "$(set -e; <"$GITHUB_API_JSON_MAIN" $JQN_CMD "$JQN_CHECK_ASSETS_SIZE")" -le "0" ] || \
          ! eval "$(set -e; <"$GITHUB_API_JSON_MAIN" $JQN_CMD "$JQN_CHECK_DOWNLOAD_URLS")"; then
       echo -en "\n\n\033[1;38;5;160m***ERROR***\033[m: debian package not"
       echo -e " accessible through Github API, exiting...\n"
       exit "$EXIT_FAILURE"
    # If the latest version of the software is listed in the JSON document as a 
    #     "prerelease", warn the user about the "prerelease" status and ask
    #     if the user still wishes to continue with installing a "prerelease"
    #     version of the software...
    elif eval "$(set -e; <"$GITHUB_API_JSON_MAIN" $JQN_CMD "$PRERELEASE_VAL_JQN_FILTER")"; then
       echo -en "\n\n\033[1;38;5;226m***Warning***\033[m: the latest release is"
       echo " a prerelease."
       local user_input=""
       user_prompt="   Do you wish to continue with the installation? [Y/N] "
       read -p "$user_prompt" -r user_input
       # Keep obtaining user input until the user has entered a valid response.
       while [ "$user_input" != "Y" ] && [ "$user_input" != "N" ]; do
          read -p "$user_prompt" -r user_input
       done
       echo
       # If the user DOESN'T wish to install a "prerelease" version of
       #     the software, then exit this script and make sure to
       #     delete all files cached from GitHub by setting "USER_INSTALLED"
       #     to "yes" to trigger the "signal_handler" function (defined
       #     below) to remove the cached files before exiting.
       if [ "$user_input" = "N" ]; then
          USER_INSTALLED="yes"
          exit "$EXIT_SUCCESS"
       fi
    fi
    echo "."
    # Get the download link and associated hash digest of every asset listed in the
    #     JSON document downloaded from GitHub (i.e. the JSON document containing urls
    #     of all of the downloadable assets of the latest version of the software to
    #     be installed)
    download_links_n_digests="$(set -e; <"$GITHUB_API_JSON_MAIN" $JQN_CMD "$JQN_GET_URLS_N_DIGESTS")"
    # Get the download link and associated hash digest of the debian package of the
    #     software using a "grep" filter and then delete the JSON document once we've
    #     successfully obtained the download link and digest (by using grep to grab the
    #     link with the ".deb" extension in the link).
    deb_pkg_url_n_digest="$(set -e; echo "$download_links_n_digests" | \
                                grep --before-context=1 --perl-regexp "$DEB_REGEX" | \
                                              sed "s/^[[:blank:]]*//;s/[[:blank:]]*\$//")"
    # Globbing and word splitting intentional here
    #shellcheck disable=SC2086   
    test $? && rm $REMOVE_OPTS "$GITHUB_API_JSON_MAIN"
    deb_pkg_url="$(set -e; echo "$deb_pkg_url_n_digest" | tail -n1 | cut -d" " -f2- | sed "s/^\"//;s/\"$//")"
    asset_digest_sha256=$(set -e; echo "$deb_pkg_url_n_digest" | head -n1 | \
                                  cut -d" " -f2- | sed "s/^\"sha256://;s/\",$//")
    # Next four lines of code inform the user that we're now downloading the
    #     debian package of the software and downloads the package using curl
    #     while outputting the download progress to the user.
    deb_pkg_filename="$(set -e; basename "$deb_pkg_url")"
    echo -e "\nFetching release debian package \"$deb_pkg_filename\"...\n\033[1;7m"
    # Globbing and word splitting intentional here
    #shellcheck disable=SC2086
    curl $CURL_NON_OUTPUT_OPTS "$deb_pkg_url" --output "$deb_pkg_filename"
    validate_package "$deb_pkg_filename" "$asset_digest_sha256" "$REPO_QUERY_URL"
    echo -ne "\033[m"
    # Inform user that we need "sudo" password to install the
    #     debian package.
    echo -e "\n\nSome of the following operations require \"sudo --set-home\" (without the"
    echo "     quotes), please enter your sudo password when prompted."
    echo "     Installing $package_name..."
    # Install debian package using "dpkg"; if the
    #     install was successful, let user know that it was
    #     successful and set "USER_INSTALLED" flag variable
    #     to yes (so that the "signal_handler" can cleanup
    #     all cached contents from GitHub later)...
    if $SUDO_COMMAND dpkg --install "$deb_pkg_filename"; then
       echo "Success!" && USER_INSTALLED="yes"
    # Otherwise, notify user that there was an error and
    #     do NOT change flag variable "USER_INSTALLED"
    #     so that the cached files from GitHub are not
    #     removed so that the files can be inspected later
    #     for debugging purposes.
    else
       echo "Oops, something went wrong during installation; please fix errors and try again."
    fi

    echo -e "\n---program complete---"

}

# Function responsible for clearing this script's
#     output (per user's request) after the "main"
#     function has exited/completed all of its tasks.
function cleanup_output() {

    local user_input=""
    user_prompt="   Do you wish to clear the terminal before exiting? [Y/N] "
    # Keep reading and discarding inputs until user has
    #     entered a valid input
    read -p "$user_prompt" -r user_input
    while [ "$user_input" != "Y" ] && [ "$user_input" != "N" ]; do
       read -p "$user_prompt" -r user_input
    done
    echo
    # Clear terminal if user wishes to do so.
    if [ "$user_input" = "Y" ]; then
       clear
    fi

}

# Space-delimited list of all signals that by default will cause
#     a process to produce a core dump after terminating.  For
#     the process that runs this script, receiving one of these
#     signals means that the process should not delete any files
#     cached from GitHub before exiting. 
CORE_TYPE_SIGS="ERR QUIT ILL TRAP ABRT BUS FPE SEGV XCPU XFSZ SYS"
# Space-delimited list of all signals that by default will cause
#     a process to simply terminate without producing any sort
#     of core dump.  For the process running this script, receiving
#     one of these signals means to delete the entire working
#     directory used to cache GitHub downloads before exiting
#     IF the user has already installed the package.
TERM_TYPE_SIGS="EXIT HUP INT KILL USR1 USR2 PIPE ALRM TERM STKFLT VTALRM PROF IO PWR"
# Combined list of all signals that the process running this script
#     should respond to.
ALL_SIGS_TO_TRAP="$TERM_TYPE_SIGS $CORE_TYPE_SIGS"

# Function used to handle inter-process signals sent to this script;
#     the parameter to this function is the string representation of
#     the signal sent to this script.
signal_handler() {
   # Constant denoting that user has installed the package
   # false positive for signal handler; applies to every instance of disabling SC2317
   #     in this function
   #shellcheck disable=SC2317
   local -r USER_INSTALLED_CONSTANT="yes"
   # Get list of all other inter-process signals that each instance of
   #     this function was assigned to handle, so that this script
   #     may clear the traps assigned to those signals when this
   #     script terminates; set -e takes care of SC2155, and SC2001
   #     is ignored due to needing to use variable replacement.
   #shellcheck disable=SC2317,SC2155,SC2001
   local sigs_to_clear_trap="$(set -e; echo "$ALL_SIGS_TO_TRAP" | sed "s/$1 //")"
   # Initialize exit code
   #shellcheck disable=SC2317
   local exit_code="$EXIT_SUCCESS"
   # Change back to the working directory this script was initially assigned
   #     to when this script started running.
   #shellcheck disable=SC2317
   cd "$PRE_SCRIPT_RUN_PWD"
   # If this script received a signal that doesn't result in a core
   #     dump by default (under POSIX-compliant OS's) AND the user
   #     has installed the package, then remove the temporary working
   #     directory this script was using earlier to cache downloads
   #     from GitHub.
   #shellcheck disable=SC2317
   if echo "$TERM_TYPE_SIGS" | grep --quiet "$1" && \
                          [ "$USER_INSTALLED" = "$USER_INSTALLED_CONSTANT" ]; then
      rm -rf "$TEMP_WORKING_DIR"
      # Notify user temporary directory has been deleted.
      echo -e "Deleted temporary directory \"$TEMP_WORKING_DIR\"...\n"
   fi
   # Next "if...elif...fi" statement/blocks of code compute
   #     the appropriate value of the exit code with which
   #     this script should exit.
   #shellcheck disable=SC2317
   if [ "$1" = "ERR" ]; then
      exit_code="$EXIT_FAILURE"
   elif [ "$1" != "EXIT" ]; then
      local kill_sig_sym="$1"
      if [ "$kill_sig_sym" = "IO" ]; then # "IO" signal is synonymous with "POLL" signal
         kill_sig_sym="POLL"
      fi
      # set -e takes care of SC2155
      #shellcheck disable=SC2155
      local kill_sig_val="$(set -e; "$(set -e; which kill)" --list="$kill_sig_sym")"
      #shellcheck disable=SC2155
      local cmd_not_found_val="$(set -e; command_not_found >/dev/null 2>&1 || echo "$?")"
      exit_code=$(( 1 + "$kill_sig_val" + "$cmd_not_found_val" ))
   fi
   # globbing and word splitting intentional here
   #shellcheck disable=SC2317,SC2086
   trap - $sigs_to_clear_trap # clear traps on all other inter-process signals
   # Unset the "x" option (if the option was set) used to
   #     show each command executed by this script before
   #     exiting.
   #shellcheck disable=SC2317
   case "$-" in
      *x*) set +x;;
      *e*) set +e;;
      *u*) set +u;;
        *) ;;
   esac
   #shellcheck disable=SC2317
   if test -o pipefail; then
       set +o pipefail
   fi
   # Exit with appropriate exit code.
   #shellcheck disable=SC2317
   exit "$exit_code"
}

# For each inter-process signal that
#     the "signal_handler" function is
#     supposed to handle, set a trap
#     on each of those signals to
#     trigger the "signal_handler"
#     function with a string
#     representation of the signal
#     as the function's parameter
#     when this script has received
#     the signal.
for each_signal in $ALL_SIGS_TO_TRAP; do
    # Early expansion intentional
    #shellcheck disable=SC2064,SC2086
    trap "signal_handler $each_signal" $each_signal
done

setup_variables_and_directory
main
cleanup_output
exit "$EXIT_SUCCESS"

