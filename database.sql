--
-- PostgreSQL database dump
--

\restrict nP8YT0zAlEzzFAF8LCO0sBfGXTuAUwMjKYuAFoIdJJvwydrz8An9e3eAuiI7qUP

-- Dumped from database version 13.23
-- Dumped by pg_dump version 18.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: apply_overdue_fine(); Type: FUNCTION; Schema: public; Owner: abaran
--

CREATE FUNCTION public.apply_overdue_fine() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    days_late INT;
    fine_amount NUMERIC(8,2);
    daily_penalty CONSTANT NUMERIC(8,2) := 5.00;  -- założona stawka kary (np. 5.00 za każdy dzień spóźnienia)
BEGIN
    -- Sprawdź, czy ustawiana jest data zwrotu w rekordzie, który wcześniej nie miał daty zwrotu (czyli następuje zwrot)
    IF (NEW.return_date IS NOT NULL AND OLD.return_date IS NULL) THEN
        -- Oblicz liczbę dni spóźnienia (jeśli zwrot jest po terminie)
        IF (NEW.return_date > NEW.due_date) THEN
            days_late := NEW.return_date - NEW.due_date;
            fine_amount := days_late * daily_penalty;
            -- Dodaj wpis do tabeli payments z kwotą kary
            INSERT INTO payments(loan_id, amount, payment_date, type)
            VALUES(NEW.id, fine_amount, CURRENT_DATE, 'kara');
        END IF;
        -- Zaktualizuj status wypożyczenia na 'ZAKOŃCZONE'
        NEW.status := 'ZAKOŃCZONE';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.apply_overdue_fine() OWNER TO abaran;

--
-- Name: create_loan(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: abaran
--

CREATE FUNCTION public.create_loan(p_client_id integer, p_copy_id integer, p_days integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_loan_id INT;
    game_id INT;
    deposit NUMERIC(8,2);
    due DATE;
BEGIN
    -- Pobierz ID gry powiązanej z danym egzemplarzem oraz wymaganą kaucję za tę grę
    SELECT copies.game_id, games.deposit_amount
    INTO game_id, deposit
    FROM copies
             JOIN games ON games.id = copies.game_id
    WHERE copies.id = p_copy_id
    LIMIT 1;
    IF game_id IS NULL THEN
        RAISE EXCEPTION 'Egzemplarz o ID % nie istnieje.', p_copy_id;
    END IF;
    -- Wylicz datę zwrotu na podstawie bieżącej daty i liczby dni wypożyczenia
    due := CURRENT_DATE + (p_days || ' days')::interval;
    -- Wstaw nowy rekord wypożyczenia (loan); pole return_date pozostaje NULL, status domyślnie 'AKTYWNE'
    INSERT INTO loans(client_id, copy_id, employee_id, loan_date, due_date)
    VALUES(p_client_id, p_copy_id, NULL, CURRENT_DATE, due::DATE)
    RETURNING id INTO new_loan_id;
    -- Jeśli gra wymaga kaucji (kwota > 0), dodaj wpis płatności kaucji
    IF deposit IS NOT NULL AND deposit > 0 THEN
        INSERT INTO payments(loan_id, amount, payment_date, type)
        VALUES(new_loan_id, deposit, CURRENT_DATE, 'kaucja');
    END IF;
    RETURN new_loan_id;
END;
$$;


ALTER FUNCTION public.create_loan(p_client_id integer, p_copy_id integer, p_days integer) OWNER TO abaran;

--
-- Name: prevent_duplicate_loan(); Type: FUNCTION; Schema: public; Owner: abaran
--

CREATE FUNCTION public.prevent_duplicate_loan() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Sprawdź, czy istnieje już aktywne (niezwrócone) wypożyczenie dla danego egzemplarza
    IF EXISTS (
        SELECT 1 FROM loans
        WHERE copy_id = NEW.copy_id
          AND return_date IS NULL
    ) THEN
        RAISE EXCEPTION 'Nie można wypożyczyć: egzemplarz (copy_id=%) jest już wypożyczony!', NEW.copy_id;
    END IF;
    RETURN NEW;  -- pozwól na wstawienie rekordu jeśli egzemplarz jest wolny
END;
$$;


ALTER FUNCTION public.prevent_duplicate_loan() OWNER TO abaran;

--
-- Name: set_copy_status_on_loan_insert(); Type: FUNCTION; Schema: public; Owner: abaran
--

CREATE FUNCTION public.set_copy_status_on_loan_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE copies
  SET status = 'WYPOŻYCZONY'
  WHERE id = NEW.copy_id;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_copy_status_on_loan_insert() OWNER TO abaran;

--
-- Name: set_copy_status_on_return(); Type: FUNCTION; Schema: public; Owner: abaran
--

CREATE FUNCTION public.set_copy_status_on_return() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (NEW.return_date IS NOT NULL AND OLD.return_date IS NULL) THEN
    UPDATE copies
    SET status = 'DOSTĘPNY'
    WHERE id = NEW.copy_id;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_copy_status_on_return() OWNER TO abaran;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categories; Type: TABLE; Schema: public; Owner: abaran
--

CREATE TABLE public.categories (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text
);


ALTER TABLE public.categories OWNER TO abaran;

--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: abaran
--

CREATE SEQUENCE public.categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.categories_id_seq OWNER TO abaran;

--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: abaran
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: clients; Type: TABLE; Schema: public; Owner: abaran
--

CREATE TABLE public.clients (
    id integer NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    email character varying(100) NOT NULL,
    phone character varying(20),
    registration_date date DEFAULT CURRENT_DATE NOT NULL,
    status character varying(20) DEFAULT 'AKTYWNY'::character varying NOT NULL
);


ALTER TABLE public.clients OWNER TO abaran;

--
-- Name: clients_id_seq; Type: SEQUENCE; Schema: public; Owner: abaran
--

CREATE SEQUENCE public.clients_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.clients_id_seq OWNER TO abaran;

--
-- Name: clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: abaran
--

ALTER SEQUENCE public.clients_id_seq OWNED BY public.clients.id;


--
-- Name: copies; Type: TABLE; Schema: public; Owner: abaran
--

CREATE TABLE public.copies (
    id integer NOT NULL,
    game_id integer NOT NULL,
    condition character varying(20) DEFAULT 'OK'::character varying NOT NULL,
    acquired_date date DEFAULT CURRENT_DATE NOT NULL,
    status character varying(20) DEFAULT 'DOSTĘPNY'::character varying NOT NULL
);


ALTER TABLE public.copies OWNER TO abaran;

--
-- Name: copies_id_seq; Type: SEQUENCE; Schema: public; Owner: abaran
--

CREATE SEQUENCE public.copies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.copies_id_seq OWNER TO abaran;

--
-- Name: copies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: abaran
--

ALTER SEQUENCE public.copies_id_seq OWNED BY public.copies.id;


--
-- Name: employees; Type: TABLE; Schema: public; Owner: abaran
--

CREATE TABLE public.employees (
    id integer NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    hire_date date DEFAULT CURRENT_DATE NOT NULL,
    "position" character varying(50),
    email character varying(100)
);


ALTER TABLE public.employees OWNER TO abaran;

--
-- Name: employees_id_seq; Type: SEQUENCE; Schema: public; Owner: abaran
--

CREATE SEQUENCE public.employees_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.employees_id_seq OWNER TO abaran;

--
-- Name: employees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: abaran
--

ALTER SEQUENCE public.employees_id_seq OWNED BY public.employees.id;


--
-- Name: game_categories; Type: TABLE; Schema: public; Owner: abaran
--

CREATE TABLE public.game_categories (
    game_id integer NOT NULL,
    category_id integer NOT NULL
);


ALTER TABLE public.game_categories OWNER TO abaran;

--
-- Name: games; Type: TABLE; Schema: public; Owner: abaran
--

CREATE TABLE public.games (
    id integer NOT NULL,
    title character varying(100) NOT NULL,
    publisher_id integer NOT NULL,
    release_year smallint,
    description text,
    deposit_amount numeric(8,2) DEFAULT 0.00 NOT NULL
);


ALTER TABLE public.games OWNER TO abaran;

--
-- Name: games_id_seq; Type: SEQUENCE; Schema: public; Owner: abaran
--

CREATE SEQUENCE public.games_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.games_id_seq OWNER TO abaran;

--
-- Name: games_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: abaran
--

ALTER SEQUENCE public.games_id_seq OWNED BY public.games.id;


--
-- Name: loans; Type: TABLE; Schema: public; Owner: abaran
--

CREATE TABLE public.loans (
    id integer NOT NULL,
    client_id integer NOT NULL,
    copy_id integer NOT NULL,
    employee_id integer,
    loan_date date DEFAULT CURRENT_DATE NOT NULL,
    due_date date NOT NULL,
    return_date date,
    status character varying(20) DEFAULT 'AKTYWNE'::character varying NOT NULL
);


ALTER TABLE public.loans OWNER TO abaran;

--
-- Name: loans_id_seq; Type: SEQUENCE; Schema: public; Owner: abaran
--

CREATE SEQUENCE public.loans_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.loans_id_seq OWNER TO abaran;

--
-- Name: loans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: abaran
--

ALTER SEQUENCE public.loans_id_seq OWNED BY public.loans.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: abaran
--

CREATE TABLE public.payments (
    id integer NOT NULL,
    loan_id integer NOT NULL,
    amount numeric(8,2) NOT NULL,
    payment_date date DEFAULT CURRENT_DATE NOT NULL,
    type character varying(20) NOT NULL
);


ALTER TABLE public.payments OWNER TO abaran;

--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: abaran
--

CREATE SEQUENCE public.payments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.payments_id_seq OWNER TO abaran;

--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: abaran
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: publishers; Type: TABLE; Schema: public; Owner: abaran
--

CREATE TABLE public.publishers (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    country character varying(50)
);


ALTER TABLE public.publishers OWNER TO abaran;

--
-- Name: publishers_id_seq; Type: SEQUENCE; Schema: public; Owner: abaran
--

CREATE SEQUENCE public.publishers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.publishers_id_seq OWNER TO abaran;

--
-- Name: publishers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: abaran
--

ALTER SEQUENCE public.publishers_id_seq OWNED BY public.publishers.id;


--
-- Name: vw_game_availability; Type: VIEW; Schema: public; Owner: abaran
--

CREATE VIEW public.vw_game_availability AS
 SELECT g.id AS game_id,
    g.title AS game_title,
    count(c.id) AS total_copies,
    count(c.id) FILTER (WHERE (l.id IS NULL)) AS available_copies
   FROM ((public.games g
     JOIN public.copies c ON ((c.game_id = g.id)))
     LEFT JOIN public.loans l ON (((l.copy_id = c.id) AND (l.return_date IS NULL))))
  GROUP BY g.id, g.title
  ORDER BY g.title;


ALTER VIEW public.vw_game_availability OWNER TO abaran;

--
-- Name: vw_overdue_loans; Type: VIEW; Schema: public; Owner: abaran
--

CREATE VIEW public.vw_overdue_loans AS
 SELECT l.id AS loan_id,
    (((cl.first_name)::text || ' '::text) || (cl.last_name)::text) AS client_name,
    cl.email AS client_email,
    g.title AS game_title,
    c.id AS copy_id,
    l.loan_date,
    l.due_date,
    (CURRENT_DATE - l.due_date) AS days_overdue
   FROM (((public.loans l
     JOIN public.clients cl ON ((cl.id = l.client_id)))
     JOIN public.copies c ON ((c.id = l.copy_id)))
     JOIN public.games g ON ((g.id = c.game_id)))
  WHERE ((l.return_date IS NULL) AND (CURRENT_DATE > l.due_date))
  ORDER BY l.due_date;


ALTER VIEW public.vw_overdue_loans OWNER TO abaran;

--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: clients id; Type: DEFAULT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.clients ALTER COLUMN id SET DEFAULT nextval('public.clients_id_seq'::regclass);


--
-- Name: copies id; Type: DEFAULT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.copies ALTER COLUMN id SET DEFAULT nextval('public.copies_id_seq'::regclass);


--
-- Name: employees id; Type: DEFAULT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.employees ALTER COLUMN id SET DEFAULT nextval('public.employees_id_seq'::regclass);


--
-- Name: games id; Type: DEFAULT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.games ALTER COLUMN id SET DEFAULT nextval('public.games_id_seq'::regclass);


--
-- Name: loans id; Type: DEFAULT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.loans ALTER COLUMN id SET DEFAULT nextval('public.loans_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: publishers id; Type: DEFAULT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.publishers ALTER COLUMN id SET DEFAULT nextval('public.publishers_id_seq'::regclass);


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: abaran
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
-- Data for Name: clients; Type: TABLE DATA; Schema: public; Owner: abaran
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
-- Data for Name: copies; Type: TABLE DATA; Schema: public; Owner: abaran
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
-- Data for Name: employees; Type: TABLE DATA; Schema: public; Owner: abaran
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
-- Data for Name: game_categories; Type: TABLE DATA; Schema: public; Owner: abaran
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
-- Data for Name: games; Type: TABLE DATA; Schema: public; Owner: abaran
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
-- Data for Name: loans; Type: TABLE DATA; Schema: public; Owner: abaran
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
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: abaran
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
-- Data for Name: publishers; Type: TABLE DATA; Schema: public; Owner: abaran
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
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: abaran
--

SELECT pg_catalog.setval('public.categories_id_seq', 10, true);


--
-- Name: clients_id_seq; Type: SEQUENCE SET; Schema: public; Owner: abaran
--

SELECT pg_catalog.setval('public.clients_id_seq', 10, true);


--
-- Name: copies_id_seq; Type: SEQUENCE SET; Schema: public; Owner: abaran
--

SELECT pg_catalog.setval('public.copies_id_seq', 64, true);


--
-- Name: employees_id_seq; Type: SEQUENCE SET; Schema: public; Owner: abaran
--

SELECT pg_catalog.setval('public.employees_id_seq', 12, true);


--
-- Name: games_id_seq; Type: SEQUENCE SET; Schema: public; Owner: abaran
--

SELECT pg_catalog.setval('public.games_id_seq', 12, true);


--
-- Name: loans_id_seq; Type: SEQUENCE SET; Schema: public; Owner: abaran
--

SELECT pg_catalog.setval('public.loans_id_seq', 18, true);


--
-- Name: payments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: abaran
--

SELECT pg_catalog.setval('public.payments_id_seq', 17, true);


--
-- Name: publishers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: abaran
--

SELECT pg_catalog.setval('public.publishers_id_seq', 10, true);


--
-- Name: categories categories_name_key; Type: CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_name_key UNIQUE (name);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: clients clients_email_key; Type: CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_email_key UNIQUE (email);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: copies copies_pkey; Type: CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.copies
    ADD CONSTRAINT copies_pkey PRIMARY KEY (id);


--
-- Name: employees employees_email_key; Type: CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_email_key UNIQUE (email);


--
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);


--
-- Name: game_categories game_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.game_categories
    ADD CONSTRAINT game_categories_pkey PRIMARY KEY (game_id, category_id);


--
-- Name: games games_pkey; Type: CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.games
    ADD CONSTRAINT games_pkey PRIMARY KEY (id);


--
-- Name: loans loans_pkey; Type: CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: publishers publishers_name_key; Type: CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.publishers
    ADD CONSTRAINT publishers_name_key UNIQUE (name);


--
-- Name: publishers publishers_pkey; Type: CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.publishers
    ADD CONSTRAINT publishers_pkey PRIMARY KEY (id);


--
-- Name: games uq_game_title_pub; Type: CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.games
    ADD CONSTRAINT uq_game_title_pub UNIQUE (title, publisher_id);


--
-- Name: loans trg_apply_overdue_fine; Type: TRIGGER; Schema: public; Owner: abaran
--

CREATE TRIGGER trg_apply_overdue_fine BEFORE UPDATE OF return_date ON public.loans FOR EACH ROW EXECUTE FUNCTION public.apply_overdue_fine();


--
-- Name: loans trg_prevent_duplicate_loan; Type: TRIGGER; Schema: public; Owner: abaran
--

CREATE TRIGGER trg_prevent_duplicate_loan BEFORE INSERT ON public.loans FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_loan();


--
-- Name: loans trg_set_copy_status_on_loan_insert; Type: TRIGGER; Schema: public; Owner: abaran
--

CREATE TRIGGER trg_set_copy_status_on_loan_insert AFTER INSERT ON public.loans FOR EACH ROW EXECUTE FUNCTION public.set_copy_status_on_loan_insert();


--
-- Name: loans trg_set_copy_status_on_return; Type: TRIGGER; Schema: public; Owner: abaran
--

CREATE TRIGGER trg_set_copy_status_on_return BEFORE UPDATE OF return_date ON public.loans FOR EACH ROW EXECUTE FUNCTION public.set_copy_status_on_return();


--
-- Name: copies copies_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.copies
    ADD CONSTRAINT copies_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(id);


--
-- Name: game_categories game_categories_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.game_categories
    ADD CONSTRAINT game_categories_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: game_categories game_categories_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.game_categories
    ADD CONSTRAINT game_categories_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(id);


--
-- Name: games games_publisher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.games
    ADD CONSTRAINT games_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id);


--
-- Name: loans loans_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: loans loans_copy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_copy_id_fkey FOREIGN KEY (copy_id) REFERENCES public.copies(id);


--
-- Name: loans loans_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id);


--
-- Name: payments payments_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: abaran
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES public.loans(id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: TABLE categories; Type: ACL; Schema: public; Owner: abaran
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.categories TO mmilek;


--
-- Name: SEQUENCE categories_id_seq; Type: ACL; Schema: public; Owner: abaran
--

GRANT ALL ON SEQUENCE public.categories_id_seq TO mmilek;


--
-- Name: TABLE clients; Type: ACL; Schema: public; Owner: abaran
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.clients TO mmilek;


--
-- Name: SEQUENCE clients_id_seq; Type: ACL; Schema: public; Owner: abaran
--

GRANT ALL ON SEQUENCE public.clients_id_seq TO mmilek;


--
-- Name: TABLE copies; Type: ACL; Schema: public; Owner: abaran
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.copies TO mmilek;


--
-- Name: SEQUENCE copies_id_seq; Type: ACL; Schema: public; Owner: abaran
--

GRANT ALL ON SEQUENCE public.copies_id_seq TO mmilek;


--
-- Name: TABLE employees; Type: ACL; Schema: public; Owner: abaran
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.employees TO mmilek;


--
-- Name: SEQUENCE employees_id_seq; Type: ACL; Schema: public; Owner: abaran
--

GRANT ALL ON SEQUENCE public.employees_id_seq TO mmilek;


--
-- Name: TABLE game_categories; Type: ACL; Schema: public; Owner: abaran
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.game_categories TO mmilek;


--
-- Name: TABLE games; Type: ACL; Schema: public; Owner: abaran
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.games TO mmilek;


--
-- Name: SEQUENCE games_id_seq; Type: ACL; Schema: public; Owner: abaran
--

GRANT ALL ON SEQUENCE public.games_id_seq TO mmilek;


--
-- Name: TABLE loans; Type: ACL; Schema: public; Owner: abaran
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.loans TO mmilek;


--
-- Name: SEQUENCE loans_id_seq; Type: ACL; Schema: public; Owner: abaran
--

GRANT ALL ON SEQUENCE public.loans_id_seq TO mmilek;


--
-- Name: TABLE payments; Type: ACL; Schema: public; Owner: abaran
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.payments TO mmilek;


--
-- Name: SEQUENCE payments_id_seq; Type: ACL; Schema: public; Owner: abaran
--

GRANT ALL ON SEQUENCE public.payments_id_seq TO mmilek;


--
-- Name: TABLE publishers; Type: ACL; Schema: public; Owner: abaran
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.publishers TO mmilek;


--
-- Name: SEQUENCE publishers_id_seq; Type: ACL; Schema: public; Owner: abaran
--

GRANT ALL ON SEQUENCE public.publishers_id_seq TO mmilek;


--
-- Name: TABLE vw_game_availability; Type: ACL; Schema: public; Owner: abaran
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.vw_game_availability TO mmilek;


--
-- Name: TABLE vw_overdue_loans; Type: ACL; Schema: public; Owner: abaran
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.vw_overdue_loans TO mmilek;


--
-- PostgreSQL database dump complete
--

\unrestrict nP8YT0zAlEzzFAF8LCO0sBfGXTuAUwMjKYuAFoIdJJvwydrz8An9e3eAuiI7qUP

