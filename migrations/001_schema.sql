--
-- PostgreSQL database dump
--

\restrict 5LmWRG97F8ysXeE4Ows8jlwMbod30nKNlVbWvfJCihtByPnjJTcWhIgrPjAreVD

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
-- Name: apply_overdue_fine(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: create_loan(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: prevent_duplicate_loan(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: set_copy_status_on_loan_insert(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: set_copy_status_on_return(); Type: FUNCTION; Schema: public; Owner: -
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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: clients; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: clients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.clients_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.clients_id_seq OWNED BY public.clients.id;


--
-- Name: copies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.copies (
    id integer NOT NULL,
    game_id integer NOT NULL,
    condition character varying(20) DEFAULT 'OK'::character varying NOT NULL,
    acquired_date date DEFAULT CURRENT_DATE NOT NULL,
    status character varying(20) DEFAULT 'DOSTĘPNY'::character varying NOT NULL
);


--
-- Name: copies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.copies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: copies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.copies_id_seq OWNED BY public.copies.id;


--
-- Name: employees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employees (
    id integer NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    hire_date date DEFAULT CURRENT_DATE NOT NULL,
    "position" character varying(50),
    email character varying(100)
);


--
-- Name: employees_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.employees_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.employees_id_seq OWNED BY public.employees.id;


--
-- Name: game_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.game_categories (
    game_id integer NOT NULL,
    category_id integer NOT NULL
);


--
-- Name: games; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.games (
    id integer NOT NULL,
    title character varying(100) NOT NULL,
    publisher_id integer NOT NULL,
    release_year smallint,
    description text,
    deposit_amount numeric(8,2) DEFAULT 0.00 NOT NULL
);


--
-- Name: games_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.games_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: games_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.games_id_seq OWNED BY public.games.id;


--
-- Name: loans; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: loans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.loans_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: loans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.loans_id_seq OWNED BY public.loans.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    id integer NOT NULL,
    loan_id integer NOT NULL,
    amount numeric(8,2) NOT NULL,
    payment_date date DEFAULT CURRENT_DATE NOT NULL,
    type character varying(20) NOT NULL
);


--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: publishers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishers (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    country character varying(50)
);


--
-- Name: publishers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishers_id_seq OWNED BY public.publishers.id;


--
-- Name: vw_game_availability; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: vw_overdue_loans; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: clients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients ALTER COLUMN id SET DEFAULT nextval('public.clients_id_seq'::regclass);


--
-- Name: copies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.copies ALTER COLUMN id SET DEFAULT nextval('public.copies_id_seq'::regclass);


--
-- Name: employees id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employees ALTER COLUMN id SET DEFAULT nextval('public.employees_id_seq'::regclass);


--
-- Name: games id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.games ALTER COLUMN id SET DEFAULT nextval('public.games_id_seq'::regclass);


--
-- Name: loans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loans ALTER COLUMN id SET DEFAULT nextval('public.loans_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: publishers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishers ALTER COLUMN id SET DEFAULT nextval('public.publishers_id_seq'::regclass);


--
-- Name: categories categories_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_name_key UNIQUE (name);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: clients clients_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_email_key UNIQUE (email);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: copies copies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.copies
    ADD CONSTRAINT copies_pkey PRIMARY KEY (id);


--
-- Name: employees employees_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_email_key UNIQUE (email);


--
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);


--
-- Name: game_categories game_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.game_categories
    ADD CONSTRAINT game_categories_pkey PRIMARY KEY (game_id, category_id);


--
-- Name: games games_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.games
    ADD CONSTRAINT games_pkey PRIMARY KEY (id);


--
-- Name: loans loans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: publishers publishers_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishers
    ADD CONSTRAINT publishers_name_key UNIQUE (name);


--
-- Name: publishers publishers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishers
    ADD CONSTRAINT publishers_pkey PRIMARY KEY (id);


--
-- Name: games uq_game_title_pub; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.games
    ADD CONSTRAINT uq_game_title_pub UNIQUE (title, publisher_id);


--
-- Name: loans trg_apply_overdue_fine; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_apply_overdue_fine BEFORE UPDATE OF return_date ON public.loans FOR EACH ROW EXECUTE FUNCTION public.apply_overdue_fine();


--
-- Name: loans trg_prevent_duplicate_loan; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_duplicate_loan BEFORE INSERT ON public.loans FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_loan();


--
-- Name: loans trg_set_copy_status_on_loan_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_copy_status_on_loan_insert AFTER INSERT ON public.loans FOR EACH ROW EXECUTE FUNCTION public.set_copy_status_on_loan_insert();


--
-- Name: loans trg_set_copy_status_on_return; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_copy_status_on_return BEFORE UPDATE OF return_date ON public.loans FOR EACH ROW EXECUTE FUNCTION public.set_copy_status_on_return();


--
-- Name: copies copies_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.copies
    ADD CONSTRAINT copies_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(id);


--
-- Name: game_categories game_categories_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.game_categories
    ADD CONSTRAINT game_categories_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: game_categories game_categories_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.game_categories
    ADD CONSTRAINT game_categories_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(id);


--
-- Name: games games_publisher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.games
    ADD CONSTRAINT games_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id);


--
-- Name: loans loans_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: loans loans_copy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_copy_id_fkey FOREIGN KEY (copy_id) REFERENCES public.copies(id);


--
-- Name: loans loans_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id);


--
-- Name: payments payments_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES public.loans(id);


--
-- PostgreSQL database dump complete
--

\unrestrict 5LmWRG97F8ysXeE4Ows8jlwMbod30nKNlVbWvfJCihtByPnjJTcWhIgrPjAreVD

