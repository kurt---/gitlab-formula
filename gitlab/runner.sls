{% from "gitlab/map.jinja" import gitlab with context %}

include:
  - users

apt-key:
 cmd.run:
  - name: apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 14219A96E15E78F4
  - require_in:
    - pkgrepo: repo-gitlab-ci-multi-runner

repo-gitlab-ci-multi-runner:
  pkgrepo.managed:
    - humanname: gitlab-ci-multi-runner
    - name: deb https://packages.gitlab.com/runner/gitlab-ci-multi-runner/ubuntu/ trusty main
    - key_url: https://packagecloud.io/gpg.key
    - require_in:
      - pkg: package-gitlab-ci-multi-runner

package-gitlab-ci-multi-runner:
  pkg.installed:
    - name: gitlab-ci-multi-runner
    - require:
      - user: gitlab-runner

{% if gitlab.enabled %}
register-runner:
  cmd.run:
    - name: gitlab-runner register --executor shell --tag-list {{ grains['fqdn'] }},{{gitlab.identifier}} --name {{ grains['fqdn'] }}-{{gitlab.identifier}}-{{ grains['machine_id'] }} --non-interactive --url {{ gitlab.url }} --registration-token {{ gitlab.token }}
    - unless:
      - grep 'url = "{{ gitlab.url }}"' /etc/gitlab-runner/config.toml
      - grep 'token = "{{ gitlab.token }}"' /etc/gitlab-runner/config.toml
      - grep 'tags = "{{ grains['fqdn'] }},{{gitlab.identifier}}"' /etc/gitlab-runner/config.toml
      - grep 'name = "{{ grains['fqdn'] }}-{{gitlab.identifier}}-{{ grains['machine_id'] }}"' /etc/gitlab-runner/config.toml
    - require:
      - pkg: package-gitlab-ci-multi-runner


install-runner:
  cmd.run:
    - name: gitlab-runner install --user gitlab-runner --working-directory /home/gitlab-runner/
    - creates: /etc/init/gitlab-runner.conf
    - require:
      - cmd: register-runner



start-runner:
  cmd.run:
    - name: gitlab-runner start
    - require:
      - cmd: install-runner
    - onlyif:
      - cmd: pgrep -f gitlab-ci-multi-runner

{% endif %}




github-gitlab-ci-runner:
  ssh_known_hosts:
    - present
    - name: github.com
    - user: gitlab-runner
    - enc: ssh-rsa
    - fingerprint: {{ salt['pillar.get']('github:fingerprint') }}
    - require:
      - user: gitlab-runner
