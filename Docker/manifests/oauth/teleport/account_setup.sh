#!/bin/bash

# Add user and roles (access|editor|auditor)
docker exec <teleport_container_id> tctl users add username --roles=access,editor,auditor --logins=root,ubuntu

# Example
docker exec teleport tctl users add namtrile --roles=access,editor,auditor --logins=root,ubuntu
