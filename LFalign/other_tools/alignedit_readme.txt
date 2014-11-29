LF Alignment Editor 1.4


To open a file, launch the  program and click File/Open. Only ASCII file names and paths are supported, just like with LF Aligner, i.e. if you have a file named ű.txt, you have to rename it before you can open it. You can also launch the editor with a file already open by passing the file path as a command line argument (i.e. LF_alignment_editor.exe "c:\some_folder\subfolder\tabbedfile.txt"). Files with names like íóüö.txt can be opened in this manner. Files must be tab separated and in UTF-8 encoding.

You can adjust the width of the columns by dragging the borders. After changing column widths, click Edit/Readjust row height.

Use the buttons at the bottom to pair up sentences. Start at the top and work your way down. You can delete rows using Edit/Delete active row. You can move blocks of cells down or up by repeatedly clicking the Split or Merge button. In very large tables (5000 rows and up), Shift up and Shift down can be slow as they need to redraw the whole table. Use Split and Merge instead whenever you can.
Apart from F1, F2, F3 and F4, you can also use Ctrl-D to merge, Ctrl-G to split, Ctrl-R to shift up and Ctrl-F to shift down (arranged in an up-down-left-right pattern designed to be used with your left hand while your right hand is on the mouse).
You can delete the content of the active row with F5 or Ctrl-W, and you can delete the content of the active cell with Shift-F5. Shift-F1 merges the entire active row with the next row.
There are also three convenience commands mapped to F6, F7 and F8. F6 moves the next non-empty cell below the active cell up into the active cell. Shift-F6 moves the next non-empty cell above the active cell down into the active cell. F7 splits the active cell at the cursor location just like the normal Split command, but instead of moving the bottom part down, it moves the top part up to the row above. F8 splits the active cell, but instead of merging the second half of the cell into the cell below, it pushes the rest of the column down.

You can use the mouse wheel or PgUp/PgDn to scroll, and the arrow keys to move the selection in the table. Ctrl-up/down jumps to the beginning/end of the active cell, Ctrl-left/right jumps one word back/forward and Shift-left/right moves the cursor left/right by one character. Ctrl-Alt-left/right jumps back/forward by one sentence within the cell.

Use Edit/Jump to next empty cell, F12 or Ctrl-J to jump to the next row that contains an empty cell. This is useful if you want to do a reasonably thorough review of a file without painstakingly going through every single sentence (empty cells tend to occur wherever there is a significant alignment problem, so you'll catch all the major problem sections this way).

Edit/Realign all below active row runs Hunalign on the portion of the first two columns that is below the active row. Use this in the rare cases when an alignment is pushed badly out of sync from a certain point all the way down to the end.

Only the last operation can be undone. Your changes are saved back to the original txt file and saving cannot be undone, so if you need a backup, make one yourself before launching the editor. Ctrl-S (or File/Save) saves the current state to file. It's good practice to hit Ctrl-S every now and then to prevent data loss. Note that saving removes empty lines. Use File/Save & exit to quit. Close the window with the X if you want to quit without saving your recent changes to the file. Any changes not saved to the file using Save or Save & exit will be lost if you close the window or your computer crashes etc.

Due to a bug that is outside my control, the vertical scrollbar may not show up in some cases. Resize the window to make it pop up. Due to another bug, the cursor may not always go where you click.