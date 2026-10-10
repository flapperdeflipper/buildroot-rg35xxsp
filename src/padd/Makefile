PKG_CONFIG ?= pkg-config
PREFIX ?= /usr

CFLAGS ?= -O2
override CFLAGS += -std=gnu11 -Wall -Wextra -Wno-unused-parameter $(shell $(PKG_CONFIG) --cflags libevdev)
override LDLIBS += $(shell $(PKG_CONFIG) --libs libevdev)

rgos-padd: padd.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< $(LDLIBS)

install: rgos-padd
	install -D -m 0755 rgos-padd $(DESTDIR)$(PREFIX)/bin/rgos-padd

clean:
	rm -f rgos-padd

.PHONY: install clean
