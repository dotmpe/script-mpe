default:

SYNC_EXCL := '*.zip' webcam '*.img' '.*.sw*' .git .gitignore .gitmodules .DS_Store

RSYNC_FLAGS := -avzui $(addprefix --exclude ,$(SYNC_EXCL))

sync-remote:
	rsync $(RSYNC_FLAGS)   ./  raspb1:/opt/raspberry-pi
sync-local:
	rsync $(RSYNC_FLAGS)   raspb1:/opt/raspberry-pi/  .

