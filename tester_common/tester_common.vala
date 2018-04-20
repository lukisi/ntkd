/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2017-2018 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 *
 *  Netsukuku is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Netsukuku is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Netsukuku.  If not, see <http://www.gnu.org/licenses/>.
 */

const int TESTER_SERVER01_ID01 = 87104682;
const int TESTER_SERVER01_NETWORK01 = 1675097918;

const int TESTER_SERVER02_ID01 = 1596432545;
const int TESTER_SERVER02_NETWORK01 = 1354430125;

const int TESTER_SERVER03_ID01 = 846793969;
const int TESTER_SERVER03_NETWORK01 = 423365822;

const int TESTER_SERVER05_ID01 = 991375229;
const int TESTER_SERVER05_NETWORK01 = 1559899885;

// after 2 seconds the test begins.
const int TESTER_TIME_01 = 2000;

// hooking modules (on various servers) report signals 'another_network' for various identity-arcs.

// then, after 1 second...
const int TESTER_TIME_02 = 3000;

// SERVER01_ID02 joins network SERVER02_NETWORK01.

const int TESTER_SERVER01_ID02 = 1267178494;

// then, after 3 seconds...
const int TESTER_TIME_03 = 6000;

// hooking module on server02 report signal 'same_network' for identity-arc with server01;
// whilst hooking module on server05 report signal 'another_network' for identity-arc with server01.
// thanks to new qspn_arc server01 bootstraps.

// then, after 1 second...
const int TESTER_TIME_04 = 7000;

// SERVER03_ID02 joins network SERVER02_NETWORK01.

const int TESTER_SERVER03_ID02 = 399143400;

// then, after 3 seconds...
const int TESTER_TIME_05 = 10000;

// hooking module on server02 report signal 'same_network' for identity-arc with server03.
// thanks to new qspn_arc server03 bootstraps.

// then, after 1 second...
const int TESTER_TIME_06 = 11000;

// SERVER01_ID03, SERVER02_ID02, SERVER03_ID03, all joins network SERVER02_NETWORK01.
// They all do prepare_enter, then wait 1 more second, then do finish_enter.

const int TESTER_SERVER01_ID03 = 659630486;
const int TESTER_SERVER02_ID02 = 1176976973;
const int TESTER_SERVER03_ID03 = 1721517748;

// then, after 5 seconds... + 1 second per wait between prepare_enter and finish_enter...
const int TESTER_TIME_07 = 17000;



const int TESTER_TIME_08 = 90000;
const int TESTER_TIME_09 = 90000;
const int TESTER_TIME_10 = 90000;
const int TESTER_TIME_11 = 90000;
const int TESTER_TIME_12 = 90000;
const int TESTER_TIME_13 = 90000;
const int TESTER_TIME_14 = 90000;
const int TESTER_TIME_15 = 90000;
const int TESTER_TIME_16 = 90000;
const int TESTER_TIME_17 = 90000;
const int TESTER_TIME_18 = 90000;
const int TESTER_TIME_19 = 90000;
const int TESTER_TIME_20 = 90000;

