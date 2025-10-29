# Infrastructure Setup

Use this `ansible-playbook` to install required services and tools for `fs-study` project. The playbook allows you to install `NginX`, `SQLite`, and `MySQL` on a host. It also allows installing `LTTng` for tracing and `docker` for containers.

Adjust your hosts in the `hosts` file then pass it to the main playbook.

```bash
# this runs the main playbook, you can run individuals from playbooks directory
ansible-playbook -i hosts site.yml
```

To test your hosts you can also run:

```bash
ansible all -i hosts -m ping
```

NOTE: To setup database hosts, you have to pass `sqlite` or `mysql` as a tag.

```bash
# this will setup mysql on dbservers group
ansible-playbook -i hosts site.yml --tags mysql
```

NOTE: To cleanup each playbook, pass the `cleanup` tag.

```bash
# this will uninstall every package that was installed by this playbook
ansible-playbook -i hosts site.yml --tags cleanup
```

## References

- [Ansible Docs](https://docs.ansible.com/ansible/2.8/user_guide/playbooks_best_practices.html#best-practices)
