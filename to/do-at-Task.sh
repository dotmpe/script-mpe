#!/bin/sh


htd_tasks__at_Task()
{
  # Inherit, mix functions..
  htd_tasks__at_Item
  htd_tasks__at_Record
}

# Open/close involves storage and locking
htd_tasks__at_Task_open
htd_tasks__at_Task_close
# Adding/removing of tag to line
htd_tasks__at_Task_add
htd_tasks__at_Task_exists
htd_tasks__at_Task_remove
# Ensuring the item is valid
htd_tasks__at_Task_process
htd_tasks__at_Task_is_clean_or_dirty
htd_tasks__at_Task_is_valid
# In case of backends, commit + push changes
htd_tasks__be_gtasks_commit
# Add attributes?
htd_tasks__be_gtasks_assert

