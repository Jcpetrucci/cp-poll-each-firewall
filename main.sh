#!/bin/bash
# Poll each firewall managed by this device and retrieve the installed policy name / date -- John C. Petrucci

hr(){
  printf '%*s\n' "${1-50}" | sed 's/ /=/g'
}

. /opt/CPshared/5.0/tmp/.CPprofile.sh # Source Check Point environment variables
mdsenv && mcd > /dev/null 2>&1 # Begin in MDS context

for customer in $MDSDIR/customers/*; do
  customer="${customer##*/}" # Convert directory path to customer name (last chunk)
  mdsenv $customer > /dev/null 2>&1 || { printf 'Unable to "mdsenv" as "%s".\n' $customer >&2; exit 1; }
  mcd > /dev/null 2>&1 || { printf 'Unable to "mcd" as "%s".\n' $customer >&2; exit 1; }
  printf '\nGateways on %s:\n' "$customer"
  hr # Horizontal separator
  while read -r resp_name resp_ipaddr resp_swver resp_platform; do
    (( responses == 0 )) && printf '%s; %s; %s; %s; %s; %s\n' Name IP Version Platform 'Policy Name' 'Policy Install Date' # Print header on first line only
    policy_name="$(cpstat fw -h ${resp_name:-NULL} -f policy 2>&1 | awk '/Policy name:/{print $NF}')" # Secondary query using `cpstat' to find policy information.
    policy_time="$(cpstat fw -h ${resp_name:-NULL} -f policy 2>&1 | sed -n -r 's/Policy install time: +(.*)/\1/p')"
    printf '%s; %s; %s; %s; %s; %s\n' "$resp_name" "$resp_ipaddr" "$resp_swver" "$resp_platform" "${policy_name:-ERROR}" "${policy_time:-ERROR}"
    (( responses ++ )) # Increment response counter so that headers do not print again
  done < <(cpmiquerybin attr "" network_objects \
    "connection_state='communicating' & \
      (\
      type='gateway' | \
      type='gateway_cluster' | \
      type='cluster_member' & ! vs_cluster_member='true' \
      ) | \
    vs_cluster_netobj='true'" \
    -a __name__,ipaddr,svn_version_name,appliance_type) | column -t -s ';'
done
