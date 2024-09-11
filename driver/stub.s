.intel_syntax noprefix

.extern _EStartup
.extern ___eapp_info

.global _krnl_MMain
.global _krnl_MMalloc
.global _krnl_MMallocNoCheck
.global _krnl_MFree
.global _krnl_MRealloc
.global _krnl_MCallKrnlLibCmd
.global _krnl_MCallDllCmd
.global _krnl_MCallLibCmd
.global _krnln_MGetDllCmdAdr
.global _krnl_MExitProcess
.global _krnl_MLoadBeginWin
.global _krnl_MMessageLoop
.global _krnl_MOtherHelp
.global _krnl_MReadProperty
.global _krnl_MReportError
.global _krnl_MWriteProperty
.global _krnl_ProcessNotifyLib

.text

_krnl_MMain:
  ret
_krnl_MMalloc:
  ret
_krnl_MMallocNoCheck:
  ret
_krnl_MFree:
  ret
_krnl_MRealloc:
  ret
_krnl_MCallKrnlLibCmd:
  ret
_krnl_MCallDllCmd:
  ret
_krnl_MCallLibCmd:
  ret
_krnln_MGetDllCmdAdr:
  ret
_krnl_MExitProcess:
  ret
_krnl_MLoadBeginWin:
  ret
_krnl_MMessageLoop:
  ret
_krnl_MOtherHelp:
  ret
_krnl_MReadProperty:
  ret
_krnl_MReportError:
  ret
_krnl_MWriteProperty:
  ret
_krnl_ProcessNotifyLib:
  ret
