#!/usr/bin/env ansible-playbook
---
- name: Setup User Profile
  hosts: localhost
  connection: local
  gather_facts: true

  tasks:
    - name: #### Configure base folder structures ####
      block:

        - name: Create .config directory
          file:
            path: ~/.config
            state: directory
            mode: 0700

    - name: #### Configure vimrc ####
      when: vimrc_configure
      template:
        src: vimrc.j2
        dest: "~/.vimrc"

    - name: #### Install basics software ####
      block:

        - name: Install software on RedHat Family Systems
          yum:
            name: "{{ item }}"
            state: latest
          when: ansible_os_family == "Redhat"
          become: true
          loop: "{{ software }}"

        - name: Install software on Debian Family Systems
          yum:
            name: "{{ item }}"
            state: latest
          when: ansible_os_family == "Debian"
          become: true
          loop: "{{ software }}"

    - name: #### Install and configure Fish Shell ####
      when: fish_configure
      block:

        - name: Install Fish on RedHat Family Systems
          yum:
            name: fish
            state: latest
          when: ansible_os_family == "Redhat"
          become: true
        
        - name: Install Fish on Debian Family Systems
          apt:
            name: fish
            state: latest
          when: ansible_os_family == "Debian"
          become: true

        - name: Create .config/fish directory
          file: 
            path: ~/.config/fish
            state: directory
            mode: 0700

        - name: Create .config/fish/completions directory
          file: 
            path: ~/.config/fish/completions
            state: directory
            mode: 0700

        - name: Create .config/fish/functions directory
          file: 
            path: ~/.config/fish/functions
            state: directory
            mode: 0700

        - name: "Configure User {{ ansible_user }} default shell as Fish"
          user:
            name: "{{ ansible_user }}"
            shell: /usr/bin/fish
          become: true

        - name: Configure custom fish shell functions
          template:
            src: "{{ item }}.j2"
            dest: "~/.config/fish/functions/{{ item }}"
          loop: "{{ fish_functions }}"

    - name: #### Install and configure ASDF ####
      when: asdf_configure
      block:

      - name: Checkout asdf repository
        git:
          repo: https://github.com/asdf-vm/asdf.git
          dest: ~/.asdf
          version: "{{ asdf_version }}"

      - name: #### Configure ASDF for Fish ####
        when: asdf_fish_enabled
        block:

        - name: Append settings to config.fish file
          lineinfile:
            path: ~/.config/fish/config.fish
            regexp: '^source\s~/\.asdf/asdf\.fish'
            line: source ~/.asdf/asdf.fish
            create: yes
 
        - name: Copy ASDF completion files
          copy:
            src: ~/.asdf/completions/asdf.fish
            dest: ~/.config/fish/completions
            remote_src: yes
            mode: 0644

    - name: #### Install applications using ASDF ####
      when: asdf_configure and asdf_application_install
      ignore_errors: yes
      block:

        - name: ASDF add plugins
          shell: "{{ ansible_env.HOME}}/.asdf/bin/asdf plugin add {{ item.name }}"
          loop: "{{ asdf_applications }}"

        - name: ASDF install applications
          shell: "{{ ansible_env.HOME}}/.asdf/bin/asdf install {{ item.name }} {{ item.version }}"
          loop: "{{ asdf_applications }}"

        - name: ASDF set global
          shell: "{{ ansible_env.HOME}}/.asdf/bin/asdf global {{ item.name }} {{ item.version }}"
          loop: "{{ asdf_applications }}"
