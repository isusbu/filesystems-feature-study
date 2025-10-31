# Infrastructure Setup

Use this `ansible-playbook` to install required services and tools for `fs-study` project.

Playbook installs:

- `NginX`
- `SQLite`
- `MySQL`
- `Docker`
- `LTTng`

## Setup the Inventory

Adjust your hosts in the `hosts.ini` file then pass it to the main playbook.

```bash
# this runs the main playbook, you can run individuals from playbooks directory
ansible-playbook -i hosts site.yml
```

To test your hosts you can also run:

```bash
ansible all -i hosts -m ping
```

## Setup the sudo passwords

Since all playbooks need sudo access, to provide the passwords you can run all scripts with `-K` or `--ask-become-pass`. One other solution would be to create a file for each group in the `group_vars` directory using this signature `group_vars/{{group}}/vaule.yml` and add the `ansible_become_pass: your_sudo_password` in that file.

Then run the `ansible-vault encrypt group_vars/{{group}}/vault.yml` command to encrypt it (all vault files are gitignored).

## Individual playbook setup

NOTE: To setup database hosts, you have to pass `sqlite` or `mysql` as a tag.

```bash
# this will setup mysql on dbservers group
ansible-playbook -i hosts playbooks/dbservers.yml --tags mysql
```

## History of Ansible commands that we used

```bash
# only installing the web-servers
ansible-playbook -i production.ini playbooks/webservers.yml
```

## References

- [Ansible Docs](https://docs.ansible.com/ansible/2.8/user_guide/playbooks_best_practices.html#best-practices)
