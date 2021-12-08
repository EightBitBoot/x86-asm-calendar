@tasm /la %1
@if errorlevel 1 goto error
@tlink /t %1
@goto end

:error
@echo ******************************* ERROR ASSEMBLING SOURCE.

:end


