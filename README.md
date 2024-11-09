# Why is this project archived?
TL;DR: It wasn't as "easy" as the name suggested, and took too much time to develop, test and debug.

**Long version**

When developing ansible-easy-vpn, I tried to come up with an easy turn-key solution that would work for everyone, no matter their knowledge of Docker, Ansible, Linux, etc.

Unfortunately, due to just how different OS configurations and environments are across different VPS/cloud providers, this playbook does not work everywhere.

Moreover, by presenting it as an "easy" solution that doesn't require a deep knowledge of Linux shell, Ansible or Docker, I obfuscated a lot of complexities in the setup, making it difficult for the end user to fix any potential errors. 

At the same time, the errors in question were tricky to debug for me, since I'm not [eating my own dogfood](https://en.wikipedia.org/wiki/Eating_your_own_dog_food) and do not have time to test this playbook on every popular VPS/cloud server there is.

Finally, this playbook was way too intrusive – it was made for setting up a single-purpose VPN server from scratch, taking care of automatic updates, SSH hardening and SSL certificates.

However, most people would want to use their VPS for things other than just a VPN server, and due to the aforementioned reasons, modifying and extending this playbook is difficult unless you know Ansible and Docker well enough.

# So what do I do now?

If you want to get rid of the services managed by this playbook, you will need to stop and remove the Docker containers, and delete their persistent storage:
```bash
docker stop authelia wg-easy adguard-unbound-doh watchtower bunkerweb
docker rm authelia wg-easy adguard-unbound-doh watchtower bunkerweb
sudo rm -rf /opt/docker
docker system prune -a
```
The configuration for unattended upgrades, SSH and the non-root user created by the playbook will remain in place.

If you're interested in a similar setup, I recommend using this project as a starting point: https://github.com/notthebee/cloud-homeserver

This Compose project sets up other services and uses Traefik instead of Bunkerweb, but follows the same purpose – running Dockerized web applications on a cloud server, protected by Authelia.

So long, and thanks for all the fish!
