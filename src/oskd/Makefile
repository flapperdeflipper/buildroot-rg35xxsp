# rgos-oskd: built by buildroot (br2-external/package/rgos-oskd), which
# passes the cross toolchain and the host wayland-scanner.

PKG_CONFIG ?= pkg-config
SCANNER ?= wayland-scanner
PREFIX ?= /usr

CFLAGS ?= -O2
override CFLAGS += -std=gnu11 -Wall -Wextra $(shell $(PKG_CONFIG) --cflags wayland-client)
override LDLIBS += $(shell $(PKG_CONFIG) --libs wayland-client)

PROTOCOL = wlr-foreign-toplevel-management-unstable-v1

all: rgos-oskd

$(PROTOCOL).h: $(PROTOCOL).xml
	$(SCANNER) client-header $< $@

$(PROTOCOL).c: $(PROTOCOL).xml
	$(SCANNER) private-code $< $@

rgos-oskd: oskd.c $(PROTOCOL).c $(PROTOCOL).h
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ oskd.c $(PROTOCOL).c $(LDLIBS)

install: rgos-oskd
	install -D -m 0755 rgos-oskd $(DESTDIR)$(PREFIX)/bin/rgos-oskd
	install -D -m 0644 oskd.conf $(DESTDIR)/etc/rgos/oskd.conf

clean:
	rm -f rgos-oskd $(PROTOCOL).c $(PROTOCOL).h

.PHONY: all install clean
