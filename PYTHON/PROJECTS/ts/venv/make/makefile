DESKTOP_DIR=/usr/share/applications
INSTALL_DIR=/usr/local/bin
SOURCE=ts.py
SOURCE_DIR=/home/kmiller/Code/LANG/Python/PROJECTS/ts/venv
TARGET=pyts
TARGET_DESKTOP=pyts.desktop
TARGET_DIR=pyts
TARGET_ICON=pyts.svg
RESOURCES=resources
TARGET_SYS_DIR=__pyscripts__

$(TARGET): $(SOURCE_DIR)/$(SOURCE)
	@echo "Converting $(SOURCE) to shell script"
	@echo "#!/usr/bin/zsh" > $(TARGET).skel
	@echo "(" >> $(TARGET).skel
	@echo "exec python3 $(INSTALL_DIR)/$(TARGET_SYS_DIR)/$(TARGET_DIR)/$(TARGET) \$$@ && echo &" >> $(TARGET).skel
	@echo ") 2>/dev/null" >> $(TARGET).skel
	@mv $(TARGET).skel $(TARGET)
	@chmod 775 $(TARGET)

clean:
	@rm -f $(TARGET)
	@rm -f $(TARGET).skel

install: $(TARGET)
	@echo "Installing source:$(TARGET) to $(INSTALL_DIR)/$(TARGET_SYS_DIR)/$(TARGET_DIR)"
	@mkdir -p $(INSTALL_DIR)/$(TARGET_SYS_DIR)/$(TARGET_DIR)
	@cp $(SOURCE_DIR)/$(SOURCE) $(INSTALL_DIR)/$(TARGET_SYS_DIR)/$(TARGET_DIR)/$(TARGET)
	@cp $(SOURCE_DIR)/$(RESOURCES)/$(TARGET_ICON) $(INSTALL_DIR)/$(TARGET_SYS_DIR)/$(TARGET_DIR)

	@echo "Installing executable:$(TARGET) to $(INSTALL_DIR)"
	@cp $(TARGET) $(INSTALL_DIR)
	
	@echo "Installing desktop file:$(TARGET_DESKTOP) to $(DESKTOP_DIR)"
	@sudo cp $(SOURCE_DIR)/$(RESOURCES)/$(TARGET_DESKTOP) $(DESKTOP_DIR)

uninstall: $(TARGET)
	@echo "Removing source:$(INSTALL_DIR)/$(TARGET_SYS_DIR)/$(TARGET_DIR)"
	@/bin/rm -rf $(INSTALL_DIR)/$(TARGET_SYS_DIR)/$(TARGET_DIR)

	@echo "Removing executable:$(INSTALL_DIR)/$(TARGET)"
	@/bin/rm -rf $(INSTALL_DIR)/$(TARGET)

	@echo "Removing desktop file:$(DESKTOP_DIR)/$(TARGET_DESKTOP)"
	@sudo /bin/rm -rf $(DESKTOP_DIR)/$(TARGET_DESKTOP)

	@/bin/rm -f $(TARGET)
