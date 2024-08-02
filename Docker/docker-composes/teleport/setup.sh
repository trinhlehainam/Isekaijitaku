# Add user and roles (access|editor|auditor)
docker exec <teleport_container_id> tctl users add username --roles=access,editor,auditor
