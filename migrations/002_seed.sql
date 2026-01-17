--
-- PostgreSQL database dump
--

\restrict 41axgs6JcJgxWSk289yilh6EDrzWsajfJ7Jr14mvypmdpbZRmHsoY39Jg15VfId

-- Dumped from database version 13.23
-- Dumped by pg_dump version 13.23

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.categories (id, name, description) FROM stdin;
1	Strategiczna	Gry wymagające planowania
2	Rodzinna	Gry dla graczy w każdym wieku
3	Imprezowa	Szybkie gry na spotkania
4	Ekonomiczna	Zarządzanie zasobami
5	Przygodowa	Eksploracja i fabuła
6	Karciana	Gry oparte na kartach
7	Logiczna	Gry logiczne i abstrakcyjne
8	Dla dzieci	Proste zasady dla najmłodszych
9	Wojenna	Symulacje konfliktów
10	Fantasy	Światy magii i miecza
\.


--
-- Data for Name: clients; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.clients (id, first_name, last_name, email, phone, registration_date, status) FROM stdin;
1	Adam	Małysz	adam@skok.pl	123456789	2026-01-16	AKTYWNY
2	Robert	Lewandowski	rl9@gol.pl	987654321	2026-01-16	AKTYWNY
3	Iga	Świątek	iga@tenis.pl	555666777	2026-01-16	AKTYWNY
4	Mariusz	Pudzianowski	pudzian@strong.pl	111222333	2026-01-16	AKTYWNY
5	Kamil	Stoch	kamil@skok.pl	444555888	2026-01-16	AKTYWNY
6	Hubert	Urbański	milionerzy@tv.pl	999888777	2026-01-16	AKTYWNY
7	Magda	Gessler	besos@kuchnia.pl	333222111	2026-01-16	AKTYWNY
8	Kuba	Wojewódzki	kuba@tvn.pl	666555444	2026-01-16	AKTYWNY
9	Sanah	Zuzia	szampan@music.pl	123123123	2026-01-16	AKTYWNY
10	Dawid	Podsiadło	malomiasteczkowy@music.pl	321321321	2026-01-16	AKTYWNY
\.


--
-- Data for Name: publishers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.publishers (id, name, country) FROM stdin;
1	Rebel	Polska
2	Galakta	Polska
3	Portal Games	Polska
4	Ravensburger	Niemcy
5	Fantasy Flight Games	USA
6	Days of Wonder	Francja
7	Czech Games Edition	Czechy
8	Asmodee	Francja
9	Z-Man Games	USA
10	Egmont	Polska
\.


--
-- Data for Name: games; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.games (id, title, publisher_id, release_year, description, deposit_amount) FROM stdin;
1	Wsiąść do Pociągu	6	2004	\N	100.00
2	Catan	2	1995	\N	80.00
3	Dobble	1	2009	\N	30.00
4	Terraformacja Marsa	1	2016	\N	150.00
5	Dixit	1	2008	\N	70.00
6	Splendor	1	2014	\N	90.00
7	Tajniacy	1	2015	\N	50.00
8	Carcassonne	8	2000	\N	60.00
9	7 Cudów Świata	1	2010	\N	110.00
10	Pandemic	9	2008	\N	95.00
11	Azul	2	2017	\N	100.00
12	Scythe	3	2016	\N	250.00
\.


--
-- Data for Name: copies; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.copies (id, game_id, condition, acquired_date, status) FROM stdin;
51	1	NOWA	2026-01-16	DOSTĘPNY
61	9	OK	2026-01-16	DOSTĘPNY
62	10	OK	2026-01-16	DOSTĘPNY
63	11	OK	2026-01-16	DOSTĘPNY
64	12	OK	2026-01-16	DOSTĘPNY
49	1	OK	2026-01-16	WYPOŻYCZONY
50	1	OK	2026-01-16	WYPOŻYCZONY
53	2	ZNISZCZONA	2026-01-16	WYPOŻYCZONY
52	2	OK	2026-01-16	WYPOŻYCZONY
54	3	OK	2026-01-16	WYPOŻYCZONY
55	4	OK	2026-01-16	WYPOŻYCZONY
56	4	OK	2026-01-16	WYPOŻYCZONY
57	5	OK	2026-01-16	WYPOŻYCZONY
58	6	OK	2026-01-16	WYPOŻYCZONY
59	7	OK	2026-01-16	WYPOŻYCZONY
60	8	OK	2026-01-16	WYPOŻYCZONY
\.


--
-- Data for Name: employees; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.employees (id, first_name, last_name, hire_date, "position", email) FROM stdin;
1	Jan	Kowalski	2026-01-16	Kierownik	j.kowalski@planszowki.pl
2	Anna	Nowak	2026-01-16	Sprzedawca	a.nowak@planszowki.pl
3	Piotr	Wiśniewski	2026-01-16	Magazynier	p.wisniewski@planszowki.pl
4	Maria	Wójcik	2026-01-16	Sprzedawca	m.wojcik@planszowki.pl
5	Krzysztof	Krawczyk	2026-01-16	Serwisant	k.krawczyk@planszowki.pl
6	Tomasz	Lewandowski	2026-01-16	Sprzedawca	t.lewandowski@planszowki.pl
7	Magdalena	Dabrowska	2026-01-16	Sprzedawca	m.dabrowska@planszowki.pl
8	Pawel	Wojcik	2026-01-16	Magazynier	p.wojcik2@planszowki.pl
9	Natalia	Kaczmarek	2026-01-16	Sprzedawca	n.kaczmarek@planszowki.pl
10	Karol	Nowicki	2026-01-16	Serwisant	k.nowicki@planszowki.pl
11	Joanna	Krol	2026-01-16	Ksiegowosc	j.krol@planszowki.pl
12	Marcin	Lis	2026-01-16	Marketing	m.lis@planszowki.pl
\.


--
-- Data for Name: game_categories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.game_categories (game_id, category_id) FROM stdin;
1	2
1	3
2	1
2	2
3	3
3	8
4	1
4	4
5	2
5	3
6	4
6	1
7	2
7	7
8	5
8	10
9	9
9	1
10	2
10	7
11	6
11	3
12	2
12	4
4	10
8	1
9	10
11	1
\.


--
-- Data for Name: loans; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.loans (id, client_id, copy_id, employee_id, loan_date, due_date, return_date, status) FROM stdin;
7	1	49	\N	2026-01-16	2026-01-23	\N	AKTYWNE
9	2	50	\N	2026-01-16	2026-01-23	\N	AKTYWNE
10	3	53	\N	2026-01-16	2026-01-19	\N	AKTYWNE
11	4	52	\N	2026-01-16	2026-01-30	\N	AKTYWNE
12	5	54	\N	2026-01-16	2026-01-21	\N	AKTYWNE
13	6	55	\N	2026-01-16	2026-01-18	\N	AKTYWNE
14	7	56	\N	2026-01-16	2026-01-20	\N	AKTYWNE
15	8	57	\N	2026-01-16	2026-01-17	\N	AKTYWNE
16	9	58	\N	2026-01-16	2026-01-18	\N	AKTYWNE
17	10	59	\N	2026-01-16	2026-01-19	\N	AKTYWNE
18	1	60	\N	2026-01-16	2026-01-23	\N	AKTYWNE
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.payments (id, loan_id, amount, payment_date, type) FROM stdin;
7	7	100.00	2026-01-16	kaucja
8	9	100.00	2026-01-16	kaucja
9	10	80.00	2026-01-16	kaucja
10	11	80.00	2026-01-16	kaucja
11	12	30.00	2026-01-16	kaucja
12	13	150.00	2026-01-16	kaucja
13	14	150.00	2026-01-16	kaucja
14	15	70.00	2026-01-16	kaucja
15	16	90.00	2026-01-16	kaucja
16	17	50.00	2026-01-16	kaucja
17	18	60.00	2026-01-16	kaucja
\.


--
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.categories_id_seq', 10, true);


--
-- Name: clients_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.clients_id_seq', 10, true);


--
-- Name: copies_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.copies_id_seq', 64, true);


--
-- Name: employees_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.employees_id_seq', 12, true);


--
-- Name: games_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.games_id_seq', 12, true);


--
-- Name: loans_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.loans_id_seq', 18, true);


--
-- Name: payments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.payments_id_seq', 17, true);


--
-- Name: publishers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.publishers_id_seq', 10, true);


--
-- PostgreSQL database dump complete
--

\unrestrict 41axgs6JcJgxWSk289yilh6EDrzWsajfJ7Jr14mvypmdpbZRmHsoY39Jg15VfId

