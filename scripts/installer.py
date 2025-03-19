#!/usr/bin/env python3

import sys
import os
import subprocess
from PyQt5.QtWidgets import (QApplication, QWizard, QWizardPage, QLabel, QVBoxLayout,
                             QHBoxLayout, QRadioButton, QComboBox, QProgressBar,
                             QPushButton, QMessageBox, QCheckBox)
from PyQt5.QtCore import Qt, QThread, pyqtSignal
from PyQt5.QtGui import QPixmap, QFont

class InstallationThread(QThread):
    progress_updated = pyqtSignal(int, str)
    finished = pyqtSignal(bool, str)

    def __init__(self, drive, partition_method, efi_partition=None, root_partition=None, home_partition=None):
        super().__init__()
        self.drive = drive
        self.partition_method = partition_method
        self.efi_partition = efi_partition
        self.root_partition = root_partition
        self.home_partition = home_partition

    def run(self):
        try:
            if self.partition_method == 'automatic':
                self.progress_updated.emit(10, 'Creating partition table...')
                subprocess.run(['parted', '-s', self.drive, 'mklabel', 'gpt'], check=True)

                self.progress_updated.emit(20, 'Creating EFI partition...')
                subprocess.run(['parted', '-s', self.drive, 'mkpart', 'primary', 'fat32', '1MiB', '512MiB'], check=True)
                subprocess.run(['parted', '-s', self.drive, 'set', '1', 'esp', 'on'], check=True)

                self.progress_updated.emit(30, 'Creating root partition...')
                subprocess.run(['parted', '-s', self.drive, 'mkpart', 'primary', 'ext4', '512MiB', '100%'], check=True)

                self.efi_partition = f'{self.drive}1'
                self.root_partition = f'{self.drive}2'

            self.progress_updated.emit(40, 'Formatting partitions...')
            subprocess.run(['mkfs.fat', '-F32', self.efi_partition], check=True)
            subprocess.run(['mkfs.ext4', self.root_partition], check=True)

            if self.home_partition:
                subprocess.run(['mkfs.ext4', self.home_partition], check=True)

            self.progress_updated.emit(50, 'Mounting partitions...')
            subprocess.run(['mount', self.root_partition, '/mnt'], check=True)
            os.makedirs('/mnt/boot/efi', exist_ok=True)
            subprocess.run(['mount', self.efi_partition, '/mnt/boot/efi'], check=True)

            if self.home_partition:
                os.makedirs('/mnt/home', exist_ok=True)
                subprocess.run(['mount', self.home_partition, '/mnt/home'], check=True)

            self.progress_updated.emit(60, 'Copying system files...')
            subprocess.run(['rsync', '-av', '/run/live/medium/casper/filesystem.squashfs/*', '/mnt/'], check=True)

            self.progress_updated.emit(70, 'Installing bootloader...')
            for dir in ['/dev', '/dev/pts', '/proc', '/sys', '/run']:
                subprocess.run(['mount', '-B', dir, f'/mnt{dir}'], check=True)

            subprocess.run(['chroot', '/mnt', 'grub-install', '--target=x86_64-efi',
                          '--efi-directory=/boot/efi', '--bootloader-id=privalinux', '--recheck'], check=True)
            subprocess.run(['chroot', '/mnt', 'update-grub'], check=True)

            self.progress_updated.emit(80, 'Configuring system...')
            subprocess.run(['chroot', '/mnt', 'apt-get', 'update'], check=True)
            subprocess.run(['chroot', '/mnt', 'apt-get', 'install', '-y',
                          'cinnamon', 'cinnamon-desktop-environment'], check=True)

            self.progress_updated.emit(90, 'Cleaning up...')
            for dir in ['/dev/pts', '/dev', '/proc', '/sys', '/run']:
                subprocess.run(['umount', f'/mnt{dir}'], check=True)

            subprocess.run(['umount', '/mnt/boot/efi'], check=True)
            if self.home_partition:
                subprocess.run(['umount', '/mnt/home'], check=True)
            subprocess.run(['umount', '/mnt'], check=True)

            self.finished.emit(True, 'Installation completed successfully!')

        except subprocess.CalledProcessError as e:
            self.finished.emit(False, f'Installation failed: {str(e)}')

class WelcomePage(QWizardPage):
    def __init__(self):
        super().__init__()
        self.setTitle('Welcome to PrivaLinux OS Installer')
        layout = QVBoxLayout()
        
        logo_label = QLabel()
        logo_path = os.path.join(os.path.dirname(__file__), '../branding/logo.svg')
        if os.path.exists(logo_path):
            pixmap = QPixmap(logo_path)
            logo_label.setPixmap(pixmap.scaled(200, 200, Qt.KeepAspectRatio, Qt.SmoothTransformation))
            layout.addWidget(logo_label, alignment=Qt.AlignCenter)

        welcome_text = QLabel(
            'This wizard will guide you through the installation of PrivaLinux OS.\n\n'
            'Please make sure you have:\n'
            '• Backed up your important data\n'
            '• At least 20GB of free disk space\n'
            '• A working internet connection'
        )
        welcome_text.setWordWrap(True)
        layout.addWidget(welcome_text)
        self.setLayout(layout)

class DrivePage(QWizardPage):
    def __init__(self):
        super().__init__()
        self.setTitle('Select Installation Drive')
        layout = QVBoxLayout()

        self.drive_combo = QComboBox()
        self.refresh_drives()

        refresh_btn = QPushButton('Refresh')
        refresh_btn.clicked.connect(self.refresh_drives)

        drive_layout = QHBoxLayout()
        drive_layout.addWidget(QLabel('Select Drive:'))
        drive_layout.addWidget(self.drive_combo)
        drive_layout.addWidget(refresh_btn)

        warning_label = QLabel(
            'WARNING: The selected drive will be completely erased!\n'
            'Make sure you have backed up all important data.'
        )
        warning_label.setStyleSheet('color: red')

        layout.addLayout(drive_layout)
        layout.addWidget(warning_label)
        self.setLayout(layout)

    def refresh_drives(self):
        self.drive_combo.clear()
        try:
            output = subprocess.check_output(['lsblk', '-d', '-n', '-p', '-o', 'NAME,SIZE,MODEL'])
            drives = output.decode().strip().split('\n')
            for drive in drives:
                if not any(x in drive for x in ['loop', 'sr0']):
                    self.drive_combo.addItem(drive)
        except subprocess.CalledProcessError:
            QMessageBox.warning(self, 'Error', 'Failed to get drive list')

    def validatePage(self):
        if not self.drive_combo.currentText():
            QMessageBox.warning(self, 'Error', 'Please select a drive')
            return False
        return True

class PartitionPage(QWizardPage):
    def __init__(self):
        super().__init__()
        self.setTitle('Partition Method')
        layout = QVBoxLayout()

        self.auto_radio = QRadioButton('Automatic Partitioning')
        self.manual_radio = QRadioButton('Manual Partitioning')
        self.auto_radio.setChecked(True)

        layout.addWidget(self.auto_radio)
        layout.addWidget(QLabel('Automatically create recommended partitions'))
        layout.addWidget(self.manual_radio)
        layout.addWidget(QLabel('Manually partition the drive using GParted'))

        self.setLayout(layout)

class InstallationPage(QWizardPage):
    def __init__(self):
        super().__init__()
        self.setTitle('Installing PrivaLinux OS')
        layout = QVBoxLayout()

        self.progress_bar = QProgressBar()
        self.status_label = QLabel('Preparing for installation...')
        
        layout.addWidget(self.progress_bar)
        layout.addWidget(self.status_label)
        self.setLayout(layout)

    def initializePage(self):
        drive = self.wizard().page(1).drive_combo.currentText().split()[0]
        partition_method = 'automatic' if self.wizard().page(2).auto_radio.isChecked() else 'manual'

        self.install_thread = InstallationThread(drive, partition_method)
        self.install_thread.progress_updated.connect(self.update_progress)
        self.install_thread.finished.connect(self.installation_finished)
        self.install_thread.start()

    def update_progress(self, value, message):
        self.progress_bar.setValue(value)
        self.status_label.setText(message)

    def installation_finished(self, success, message):
        if success:
            self.wizard().next()
        else:
            QMessageBox.critical(self, 'Installation Failed', message)

class CompletionPage(QWizardPage):
    def __init__(self):
        super().__init__()
        self.setTitle('Installation Complete')
        layout = QVBoxLayout()

        completion_text = QLabel(
            'PrivaLinux OS has been successfully installed!\n\n'
            'You can now restart your computer to begin using PrivaLinux OS.\n'
            'Make sure to remove the installation media before restarting.'
        )
        completion_text.setWordWrap(True)

        layout.addWidget(completion_text)
        self.setLayout(layout)

class InstallerWizard(QWizard):
    def __init__(self):
        super().__init__()
        self.setWindowTitle('PrivaLinux OS Installer')
        self.setWizardStyle(QWizard.ModernStyle)

        # Add pages
        self.addPage(WelcomePage())
        self.addPage(DrivePage())
        self.addPage(PartitionPage())
        self.addPage(InstallationPage())
        self.addPage(CompletionPage())

        # Set window properties
        self.setMinimumSize(600, 400)

def main():
    # Check if running with root privileges
    if os.geteuid() != 0:
        print('This installer must be run with root privileges.')
        sys.exit(1)

    # Create Qt application
    app = QApplication(sys.argv)
    
    # Set application style
    app.setStyle('Fusion')
    
    # Create and show the wizard
    wizard = InstallerWizard()
    wizard.show()
    
    # Start the application
    sys.exit(app.exec_())

if __name__ == '__main__':
    main()