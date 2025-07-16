# x86 Assembly Calendar

This is a TUI gregorian calendar written in 16 bit, intel flavored x86 assembly. It's features include incremental redraws, current date lookup (via interrupts), and accurate calendar modeling (months can be scrolled through and each shows its correct, respective start and end days of the week).

It is designed from the ground up to be run on [DOSBox](https://www.dosbox.com/) and makes use of standard DOS syscalls.

It also comes batteries-included: everything needed to build is checked into the repo and no external libraries or code are used.

# Building

1. [Install DOSBox](https://www.dosbox.com/download.php?main=1)
2. Clone this repo and make note of its local path
3. Run the following commands in DOSBox to mount the repo and included assembler and add the assembler to the path:
```batchfile
MOUNT C {absolute_path_to_repo}/cdrive
MOUNT A {absolute_path_to_repo}
C:
AUTOEXEC.BAT
```
4. Run the following commands in DOSBox to build the calendar (the first command is only necessary if the current directory is different than the `A:` drive):
```batchfile
A:
BC.BAT
```

# Running

Run the following commands in DOSBox (the first command is only necessary if the current directory is different than the `A:` drive):

```batchfile
A:
CALENDAR
```
