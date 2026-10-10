PKG_CONFIG ?= pkg-config
PREFIX ?= /usr

CFLAGS ?= -O2
override CFLAGS += -std=gnu11 -Wall -Wextra $(shell $(PKG_CONFIG) --cflags libevdev)
override LDLIBS += $(shell $(PKG_CONFIG) --libs libevdev)

rgos-padsim: padsim.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< $(LDLIBS)

install: rgos-padsim
	install -D -m 0755 rgos-padsim $(DESTDIR)$(PREFIX)/bin/rgos-padsim

clean:
	rm -f rgos-padsim

.PHONY: install clean
