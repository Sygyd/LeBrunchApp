--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2
-- Dumped by pg_dump version 17.2

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: menu; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.menu (
    idplato integer NOT NULL,
    nombre character varying(150) NOT NULL,
    categoria character varying(50) NOT NULL,
    precio numeric(10,2) NOT NULL,
    disponibilidad boolean NOT NULL,
    ingredientes text NOT NULL,
    imagen_url text
);


ALTER TABLE public.menu OWNER TO postgres;

--
-- Name: menu_idplato_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.menu_idplato_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.menu_idplato_seq OWNER TO postgres;

--
-- Name: menu_idplato_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.menu_idplato_seq OWNED BY public.menu.idplato;


--
-- Name: pedido_detalle; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pedido_detalle (
    idpedido_detalle integer NOT NULL,
    idplato integer NOT NULL,
    idpedido integer NOT NULL,
    cantidad integer DEFAULT 1,
    precio_unitario numeric(10,2),
    notas text
);


ALTER TABLE public.pedido_detalle OWNER TO postgres;

--
-- Name: pedido_detalle_idpedido_detalle_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pedido_detalle_idpedido_detalle_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pedido_detalle_idpedido_detalle_seq OWNER TO postgres;

--
-- Name: pedido_detalle_idpedido_detalle_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pedido_detalle_idpedido_detalle_seq OWNED BY public.pedido_detalle.idpedido_detalle;


--
-- Name: pedidos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pedidos (
    idpedido integer NOT NULL,
    idpersona integer NOT NULL,
    fecha timestamp without time zone DEFAULT now(),
    estado character varying(20) DEFAULT 'pendiente'::character varying
);


ALTER TABLE public.pedidos OWNER TO postgres;

--
-- Name: pedidos_idpedido_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pedidos_idpedido_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pedidos_idpedido_seq OWNER TO postgres;

--
-- Name: pedidos_idpedido_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pedidos_idpedido_seq OWNED BY public.pedidos.idpedido;


--
-- Name: personas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.personas (
    idpersonas integer NOT NULL,
    nombre character varying(100) NOT NULL,
    apellido character varying(100) NOT NULL,
    cedula character varying(20) NOT NULL,
    email character varying(150) NOT NULL
);


ALTER TABLE public.personas OWNER TO postgres;

--
-- Name: personas_idpersonas_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.personas_idpersonas_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.personas_idpersonas_seq OWNER TO postgres;

--
-- Name: personas_idpersonas_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.personas_idpersonas_seq OWNED BY public.personas.idpersonas;


--
-- Name: usuario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario (
    idpersona integer NOT NULL,
    contrasena character varying(255) NOT NULL,
    rol character varying(50) NOT NULL
);


ALTER TABLE public.usuario OWNER TO postgres;

--
-- Name: menu idplato; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.menu ALTER COLUMN idplato SET DEFAULT nextval('public.menu_idplato_seq'::regclass);


--
-- Name: pedido_detalle idpedido_detalle; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido_detalle ALTER COLUMN idpedido_detalle SET DEFAULT nextval('public.pedido_detalle_idpedido_detalle_seq'::regclass);


--
-- Name: pedidos idpedido; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedidos ALTER COLUMN idpedido SET DEFAULT nextval('public.pedidos_idpedido_seq'::regclass);


--
-- Name: personas idpersonas; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personas ALTER COLUMN idpersonas SET DEFAULT nextval('public.personas_idpersonas_seq'::regclass);


--
-- Data for Name: menu; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.menu (idplato, nombre, categoria, precio, disponibilidad, ingredientes, imagen_url) FROM stdin;
47	Tabla LB Mix	Tablas	18.00	t	Gofres, tostadas francesas (2), tequeños (3), mandocas (3), arepitas dulces (2), huevos revueltos, frutas, jamón y queso	http://192.168.1.121:3000/uploads/1744336625017.jpg
42	Gofe del Bosque	Gofres	12.00	t	Gofre tradicional acompañado de fresas, arándanos, azúcar glass, crema chantillí y jarabe de arce	http://192.168.1.121:3000/uploads/1744336696239.jpg
44	Omelette Tradicional	Omelettes	7.00	t	Omelet tradicional relleno de jamón y queso mozzarella	http://192.168.1.121:3000/uploads/1744336819621.jpg
41	Omelette Vegetariano	Omelettes	10.00	t	Jugoso omelet relleno de vegetales salteados	http://192.168.1.121:3000/uploads/1744338031195.jpg
45	Gofre LB	Gofres	13.00	f	Gofre tradicional acompañado de nuestros deliciosos tenders de suprema de pollo, bañados en azúcar glass y delicioso jarabe de arce	http://192.168.1.121:3000/uploads/1744336775342.jpg
\.


--
-- Data for Name: pedido_detalle; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pedido_detalle (idpedido_detalle, idplato, idpedido, cantidad, precio_unitario, notas) FROM stdin;
2	42	7	1	12.00	
3	47	8	1	18.00	\N
4	42	8	1	12.00	\N
5	44	8	1	7.00	\N
6	41	9	1	10.00	\N
7	47	10	2	18.00	\N
8	42	10	1	12.00	\N
9	47	11	1	18.00	\N
10	42	11	1	12.00	\N
11	44	11	1	7.00	\N
12	41	11	1	10.00	\N
\.


--
-- Data for Name: pedidos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pedidos (idpedido, idpersona, fecha, estado) FROM stdin;
7	12	2025-04-14 03:25:07.119432	pendiente
8	12	2025-04-14 15:54:06.437272	pendiente
11	12	2025-04-14 16:11:14.04235	completado
10	12	2025-04-14 16:07:37.241229	completado
9	12	2025-04-14 16:03:12.734446	completado
\.


--
-- Data for Name: personas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.personas (idpersonas, nombre, apellido, cedula, email) FROM stdin;
1	luis	luis	luis	luis
3	jose	jose	jose	jose
4	Luis	Martinez	26	laaaaaaa
7	Luis	Martinez	2614	laaaaaaaaaaa
8	Luis	Martinez	255555	luios@luis.com
9	luis	luis	25566	luis@qqqq
10	luis	luis	6655	luijom
12	Hola	Hola	99	cliente
13	si	si	1001	cli
14	123	123	123	123
15	cocina	cocina	77	cocina@gmail.com
16	luis	luis	789	luis@w.com
19	1	1	1111	admin@admin.com
20	cocina	cocina	5566	cocina@cocina.com
21	barista	barista	789654	barista@barista.com
\.


--
-- Data for Name: usuario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usuario (idpersona, contrasena, rol) FROM stdin;
7	monito	1
8	monito	1
9	cristina	1
10	$2b$10$2KNUjx4KhRFn.bTUKwArC.5nLTjautgfXFDKto92obdrSCGx.uF1S	0
12	$2b$10$W0oqEzpMxOFdtviD/.7rDes3FyRXDJ9ZKzBTUBQTW0A1XGsiltrEy	1
13	$2b$10$.A4TA.EDfirXbAF00d7Cj.aOFHogMPg9AneX8sS6vGG27nOOvYJb2	1
14	$2b$10$qdCL3WFMalQsgRXSBaKYCeLFF5dNWhRGbZ8VHhCzAAlzq3qunbwBO	1
15	$2b$10$sO41FSDbzymbS2Lm0hTl1eX8pZyTt.pi3xBsNo4KX/g6REwbUih9K	2
16	$2b$10$HETOFSYYh/B7ydqk3d8NRuE3Yi0WlvhPcsXm1KunTaLLczcvaOBui	0
19	$2b$10$7ECKYIHrT0bAxzu1Y7fu0.xdaE.kqo7bncYJ4xlTZVYGmu1WmxNkK	0
20	$2b$10$boU1X1XdXpyDJlly7BePAeN0Ce1SDyAoxW2l7282hKGSpbi.c5Fzm	2
21	$2b$10$1bWEyWgrqaZC.GbaaSgX.OpUGPZhzpF0ih20rki2hlrSGn/NzQTWa	3
\.


--
-- Name: menu_idplato_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.menu_idplato_seq', 48, true);


--
-- Name: pedido_detalle_idpedido_detalle_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.pedido_detalle_idpedido_detalle_seq', 12, true);


--
-- Name: pedidos_idpedido_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.pedidos_idpedido_seq', 11, true);


--
-- Name: personas_idpersonas_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.personas_idpersonas_seq', 21, true);


--
-- Name: menu menu_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.menu
    ADD CONSTRAINT menu_pkey PRIMARY KEY (idplato);


--
-- Name: pedido_detalle pedido_detalle_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido_detalle
    ADD CONSTRAINT pedido_detalle_pkey PRIMARY KEY (idpedido_detalle);


--
-- Name: pedidos pedidos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_pkey PRIMARY KEY (idpedido);


--
-- Name: personas personas_cedula_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personas
    ADD CONSTRAINT personas_cedula_key UNIQUE (cedula);


--
-- Name: personas personas_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personas
    ADD CONSTRAINT personas_email_key UNIQUE (email);


--
-- Name: personas personas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personas
    ADD CONSTRAINT personas_pkey PRIMARY KEY (idpersonas);


--
-- Name: usuario usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (idpersona);


--
-- Name: pedido_detalle pedido_detalle_idpedido_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido_detalle
    ADD CONSTRAINT pedido_detalle_idpedido_fkey FOREIGN KEY (idpedido) REFERENCES public.pedidos(idpedido);


--
-- Name: pedido_detalle pedido_detalle_idplato_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido_detalle
    ADD CONSTRAINT pedido_detalle_idplato_fkey FOREIGN KEY (idplato) REFERENCES public.menu(idplato);


--
-- Name: pedidos pedidos_idpersona_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_idpersona_fkey FOREIGN KEY (idpersona) REFERENCES public.personas(idpersonas);


--
-- Name: usuario usuario_idpersona_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_idpersona_fkey FOREIGN KEY (idpersona) REFERENCES public.personas(idpersonas);


--
-- PostgreSQL database dump complete
--

