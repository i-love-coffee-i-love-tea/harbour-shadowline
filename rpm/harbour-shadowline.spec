Name:       harbour-shadowline
Summary:    Shadow Line — interactive daylight globe for Sailfish OS
Version:    1.2.0
Release:    1
Group:      Utility
License:    MIT
URL:        https://github.com/gobuki/harbour-shadowline
Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5Positioning)
BuildRequires:  gcc-c++

%description
Shadow Line displays an interactive 3D globe with the day/night
terminator, showing where sunlight falls on Earth in real time.
Configure locations to see sunrise and sunset times.

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5
make %{?_smp_mflags}

%install
rm -rf %{buildroot}
%qmake5_install

for SIZE in 86 108 128 172; do
  mkdir -p %{buildroot}%{_datadir}/icons/hicolor/${SIZE}x${SIZE}/apps
  install -m 644 rpm/icons/${SIZE}x${SIZE}/%{name}.png \
    %{buildroot}%{_datadir}/icons/hicolor/${SIZE}x${SIZE}/apps/%{name}.png
done

mkdir -p %{buildroot}%{_datadir}/metainfo
install -m 644 rpm/%{name}.appdata.xml \
  %{buildroot}%{_datadir}/metainfo/%{name}.metainfo.xml

mkdir -p %{buildroot}%{_datadir}/mapplauncherd/privileges.d
install -m 644 privileges/%{name} \
  %{buildroot}%{_datadir}/mapplauncherd/privileges.d/%{name}

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
%{_datadir}/metainfo/%{name}.metainfo.xml
%{_datadir}/mapplauncherd/privileges.d/%{name}
