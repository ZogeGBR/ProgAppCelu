-- =====================================================================
-- FreshMarket: datos iniciales. Se cargan solo si no hay productos.
-- Las cuentas del dueño y del repartidor NO van acá (tendrían la clave a
-- la vista): se crean desde las variables de entorno al arrancar.
-- =====================================================================

INSERT INTO productos (id, nombre, precio, categoria, emoji) VALUES
  ('p1', 'Fideos guiseros 500g',  1200, 'Almacén',    '🍝'),
  ('p2', 'Yerba mate 1kg',        3800, 'Almacén',    '🧉'),
  ('p3', 'Leche entera 1L',       1500, 'Lácteos',    '🥛'),
  ('p4', 'Pan francés (kg)',      2200, 'Panadería',  '🥖'),
  ('p5', 'Tomate (kg)',           1800, 'Verdulería', '🍅'),
  ('p6', 'Queso cremoso (kg)',    6500, 'Lácteos',    '🧀'),
  ('p7', 'Gaseosa cola 2.25L',    2600, 'Bebidas',    '🥤'),
  ('p8', 'Papel higiénico x4',    2100, 'Limpieza',   '🧻');

-- AUTOINCREMENT sigue desde este valor: el primer pedido es el #1001.
INSERT INTO sqlite_sequence (name, seq) VALUES ('pedidos', 1000);
