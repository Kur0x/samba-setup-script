# samba-setup-script
a script to install and config samba

## Install samba
       samba_setup.sh
## Usage: 
       samba_setup.sh -l,--list                List all users
       samba_setup.sh -a,--add <user> <pass>   Add a user
       samba_setup.sh -d,--del <user>          Delete a user
       samba_setup.sh -m,--mod <user> <pass>   Modify a user's password
       samba_setup.sh -p,--privilage <user> <foler> {read|write}   Add a user's privilage
       samba_setup.sh -u,--unprivilage <user> <foler> {read|write}   Remove a user's privilage
       samba_setup.sh -f,--folder <foler>   create a folder
       samba_setup.sh -g,--delfolder <foler>   deleta a folder
       samba_setup.sh -h,--help                Print this help
       
**System Supported**: CentOS 7+ / Redhat 7+
