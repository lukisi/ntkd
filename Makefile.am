NULL = 
ACLOCAL_AMFLAGS = -I m4

SUBDIRS = \
	neighborhood \
	identities \
	qspn \
	coordinator \
	hooking \
	andna \
	$(NULL)

noinst_LTLIBRARIES = \
	libmacgetter.la \
	$(NULL)

bin_PROGRAMS =  \
	ntkd \
	ntkd_cleaning \
	ntkd_tester_01 \
	ntkd_tester_02 \
	$(NULL)

libmacgetter_la_SOURCES = \
	mac-getter/hw.c \
	mac-getter/hw.h \
	$(NULL)

libmacgetter_la_CPPFLAGS = \
	$(NULL)

libmacgetter_la_LIBADD = \
	$(NULL)

ntkd_SOURCES =  \
	ntkd.vala \
	rngen.vala \
	configuration.vala \
	startup.vala \
	mainloop.vala \
	cleanup.vala \
	ntkd_rpc.vala \
	serialize_helpers.vala \
	commander.vala \
	table_names.vala \
	ipv4_compute.vala \
	identity_ip_compute.vala \
	identity_ip_commands.vala \
	naddr.vala \
	enter_network.vala \
	migrate.vala \
	update_graph.vala \
	neighborhood_helpers.vala \
	neighborhood_signals.vala \
	identities_helpers.vala \
	identities_signals.vala \
	qspn_helpers.vala \
	qspn_signals.vala \
	peers_helpers.vala \
	mac-getter/hw.vapi \
	identities/identities.vapi \
	neighborhood/neighborhood.vapi \
	qspn/qspn.vapi \
	coordinator/coord.vapi \
	hooking/hooking.vapi \
	andna/andna.vapi \
	$(NULL)

ntkd_VALAFLAGS = \
	--vapidir $(GEE_PREFIX)/share/vala/vapi \
	--vapidir $(TASKLETSYSTEM_VAPIDIR) \
	--vapidir $(PTHTASKLET_VAPIDIR) \
	--vapidir $(NTKDCOMMON_VAPIDIR) \
	--vapidir $(NTKDRPC_VAPIDIR) \
	--vapidir $(PEERS_VAPIDIR) \
	--pkg gee-0.8 \
	--pkg ntkd-common \
	--pkg tasklet-system \
	--pkg pth-tasklet \
	--pkg ntkdrpc \
	--pkg peers \
	--pkg posix \
	$(NULL)

ntkd_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NTKDCOMMON_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(PTHTASKLET_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(PEERS_CFLAGS) \
	-I$(srcdir)/identities \
	-I$(srcdir)/neighborhood \
	-I$(srcdir)/qspn \
	-I$(srcdir)/coordinator \
	-I$(srcdir)/hooking \
	-I$(srcdir)/andna \
	$(NULL)

ntkd_LDADD = \
	-lm \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(NTKDCOMMON_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(PTHTASKLET_LIBS) \
	$(NTKDRPC_LIBS) \
	$(PEERS_LIBS) \
	$(builddir)/libmacgetter.la \
	$(builddir)/neighborhood/libneighborhood.la \
	$(builddir)/identities/libidentities.la \
	$(builddir)/qspn/libqspn.la \
	$(builddir)/coordinator/libcoord.la \
	$(builddir)/hooking/libhooking.la \
	$(builddir)/andna/libandna.la \
	$(NULL)


ntkd_cleaning_SOURCES =  \
	cleaning/cleaning.vala \
	cleaning/commander.vala \
	mac-getter/hw.vapi \
	$(NULL)

ntkd_cleaning_VALAFLAGS = \
	--vapidir $(GEE_PREFIX)/share/vala/vapi \
	--vapidir $(TASKLETSYSTEM_VAPIDIR) \
	--vapidir $(PTHTASKLET_VAPIDIR) \
	--pkg gee-0.8 \
	--pkg tasklet-system \
	--pkg pth-tasklet \
	--pkg posix \
	$(NULL)

ntkd_cleaning_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(PTHTASKLET_CFLAGS) \
	$(NULL)

ntkd_cleaning_LDADD = \
	-lm \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(PTHTASKLET_LIBS) \
	$(builddir)/libmacgetter.la \
	$(NULL)


ntkd_tester_01_SOURCES =  \
	tester_01/ntkd.vala \
	tester_01/rngen.vala \
	tester_01/configuration.vala \
	tester_01/startup.vala \
	tester_01/mainloop.vala \
	tester_01/cleanup.vala \
	tester_01/ntkd_rpc.vala \
	tester_01/serialize_helpers.vala \
	tester_01/commander.vala \
	tester_01/table_names.vala \
	tester_01/ipv4_compute.vala \
	tester_01/identity_ip_compute.vala \
	tester_01/identity_ip_commands.vala \
	tester_01/naddr.vala \
	tester_01/enter_network.vala \
	tester_01/migrate.vala \
	tester_01/update_graph.vala \
	tester_01/neighborhood_helpers.vala \
	tester_01/neighborhood_signals.vala \
	tester_01/identities_helpers.vala \
	tester_01/identities_signals.vala \
	tester_01/qspn_helpers.vala \
	tester_01/qspn_signals.vala \
	tester_01/peers_helpers.vala \
	mac-getter/hw.vapi \
	identities/identities.vapi \
	neighborhood/neighborhood.vapi \
	qspn/qspn.vapi \
	coordinator/coord.vapi \
	hooking/hooking.vapi \
	andna/andna.vapi \
	$(NULL)

ntkd_tester_01_VALAFLAGS = \
	--vapidir $(GEE_PREFIX)/share/vala/vapi \
	--vapidir $(TASKLETSYSTEM_VAPIDIR) \
	--vapidir $(PTHTASKLET_VAPIDIR) \
	--vapidir $(NTKDCOMMON_VAPIDIR) \
	--vapidir $(NTKDRPC_VAPIDIR) \
	--vapidir $(PEERS_VAPIDIR) \
	--pkg gee-0.8 \
	--pkg ntkd-common \
	--pkg tasklet-system \
	--pkg pth-tasklet \
	--pkg ntkdrpc \
	--pkg peers \
	--pkg posix \
	$(NULL)

ntkd_tester_01_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NTKDCOMMON_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(PTHTASKLET_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(PEERS_CFLAGS) \
	-I$(srcdir)/identities \
	-I$(srcdir)/neighborhood \
	-I$(srcdir)/qspn \
	-I$(srcdir)/coordinator \
	-I$(srcdir)/hooking \
	-I$(srcdir)/andna \
	$(NULL)

ntkd_tester_01_LDADD = \
	-lm \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(NTKDCOMMON_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(PTHTASKLET_LIBS) \
	$(NTKDRPC_LIBS) \
	$(PEERS_LIBS) \
	$(builddir)/libmacgetter.la \
	$(builddir)/neighborhood/libneighborhood.la \
	$(builddir)/identities/libidentities.la \
	$(builddir)/qspn/libqspn.la \
	$(builddir)/coordinator/libcoord.la \
	$(builddir)/hooking/libhooking.la \
	$(builddir)/andna/libandna.la \
	$(NULL)


ntkd_tester_02_SOURCES =  \
	tester_02/ntkd.vala \
	tester_02/rngen.vala \
	tester_02/configuration.vala \
	tester_02/startup.vala \
	tester_02/mainloop.vala \
	tester_02/cleanup.vala \
	tester_02/ntkd_rpc.vala \
	tester_02/serialize_helpers.vala \
	tester_02/commander.vala \
	tester_02/table_names.vala \
	tester_02/ipv4_compute.vala \
	tester_02/identity_ip_compute.vala \
	tester_02/identity_ip_commands.vala \
	tester_02/naddr.vala \
	tester_02/enter_network.vala \
	tester_02/migrate.vala \
	tester_02/update_graph.vala \
	tester_02/neighborhood_helpers.vala \
	tester_02/neighborhood_signals.vala \
	tester_02/identities_helpers.vala \
	tester_02/identities_signals.vala \
	tester_02/qspn_helpers.vala \
	tester_02/qspn_signals.vala \
	tester_02/peers_helpers.vala \
	mac-getter/hw.vapi \
	identities/identities.vapi \
	neighborhood/neighborhood.vapi \
	qspn/qspn.vapi \
	coordinator/coord.vapi \
	hooking/hooking.vapi \
	andna/andna.vapi \
	$(NULL)

ntkd_tester_02_VALAFLAGS = \
	--vapidir $(GEE_PREFIX)/share/vala/vapi \
	--vapidir $(TASKLETSYSTEM_VAPIDIR) \
	--vapidir $(PTHTASKLET_VAPIDIR) \
	--vapidir $(NTKDCOMMON_VAPIDIR) \
	--vapidir $(NTKDRPC_VAPIDIR) \
	--vapidir $(PEERS_VAPIDIR) \
	--pkg gee-0.8 \
	--pkg ntkd-common \
	--pkg tasklet-system \
	--pkg pth-tasklet \
	--pkg ntkdrpc \
	--pkg peers \
	--pkg posix \
	$(NULL)

ntkd_tester_02_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NTKDCOMMON_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(PTHTASKLET_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(PEERS_CFLAGS) \
	-I$(srcdir)/identities \
	-I$(srcdir)/neighborhood \
	-I$(srcdir)/qspn \
	-I$(srcdir)/coordinator \
	-I$(srcdir)/hooking \
	-I$(srcdir)/andna \
	$(NULL)

ntkd_tester_02_LDADD = \
	-lm \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(NTKDCOMMON_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(PTHTASKLET_LIBS) \
	$(NTKDRPC_LIBS) \
	$(PEERS_LIBS) \
	$(builddir)/libmacgetter.la \
	$(builddir)/neighborhood/libneighborhood.la \
	$(builddir)/identities/libidentities.la \
	$(builddir)/qspn/libqspn.la \
	$(builddir)/coordinator/libcoord.la \
	$(builddir)/hooking/libhooking.la \
	$(builddir)/andna/libandna.la \
	$(NULL)

