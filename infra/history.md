# History of Ansible commands that we used

```bash
# cleanup nginx from servers
ansible-playbook -i production.ini playbooks/webservers.yml --tags cleanup,nginx -K
```
