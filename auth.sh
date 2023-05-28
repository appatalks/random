# auth.sh v.0.0.1 Oct. 20th 2014
# Send an Email when SSH Login detected.

# Place the if - fi statements into a file in /etc/profile.d/auth.sh, assuming /etc/bashrc has that configured.
# Replace Email with your email.
# Usage: curl -s http://hoshisato.com/tools/code/auth.sh > /etc/profile.d/auth.sh && 
#        sed -i 's/destination-email/example@example.com/g' /etc/profile.d/auth.sh

if [ -n "$SSH_CLIENT" ]; then
    TEXT="$(date): ssh login to ${USER}@$(hostname -f)"
    TEXT="$TEXT from $(echo $SSH_CLIENT|awk '{print $1}')"
    echo $TEXT|mail -s "ssh login" destination-email
fi
