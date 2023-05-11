--PROCEDIMIENTOS
/*
1.Crear procedimiento que modifique el saldo de cuentas
*/
create or replace procedure realizar_transferencia(
in tipo_ varchar, 
in cuenta_ integer,
in monto_ numeric
) as $$
begin
	if tipo_ = 'ingreso' then
		--sumar en destino
		update cuentas set saldo = saldo + monto_ where id = cuenta_;
		
	elsif tipo_ = 'retiro' then
		--verificar que haya suficiente dinero en la cuenta de origen
		if(select saldo from cuentas where id = cuenta_) < monto_ then
			rollback;
			raise exception 'No hay suficiente dinero en la cuenta de origen';
		end if;
		--restar en origen
		update cuentas set saldo = saldo - monto_ where id = cuenta_;
	else
		raise exception 'Tipo de movimiento no valido';
	end if;
	-- inserta un nuevo registro en la tabla "movimientos"
	INSERT INTO movimientos (tipo_movimiento,monto) VALUES (tipo_,monto_);
	commit;
end;
$$ language plpgsql;
call realizar_transferencia('retiro',1,500);

--TRIGGERS

/*
1. Cuando se añade un movimiento se modifica el saldo
*/
CREATE OR REPLACE FUNCTION update_cuenta()
RETURNS trigger
AS $$
BEGIN
	IF new.monto < 0 THEN
		RAISE SQLSTATE '22013';
	END IF;
	IF new.tipo = 'retirar' THEN
		IF (SELECT saldo FROM cuentas WHERE id_cuenta = new.id_cuenta)<new.monto THEN
			RAISE SQLSTATE '22012';
		END IF;
		UPDATE cuentas SET saldo = saldo - new.monto WHERE id_cuenta = new.id_cuenta;
	ELSIF new.tipo = 'ingresar' THEN
		UPDATE cuentas SET saldo = saldo + new.monto WHERE id_cuenta = new.id_cuenta;
	ELSE
		RAISE SQLSTATE '22014';
	END IF;
	RETURN new;
	EXCEPTION
		WHEN SQLSTATE '22012' THEN
			RAISE NOTICE 'No tiene suficientes ingresos';
			ROLLBACK;
		WHEN SQLSTATE '22013' THEN
			RAISE NOTICE 'No puedes escribir valores negativos';
			ROLLBACK;
		WHEN SQLSTATE '22014' THEN
			RAISE NOTICE 'Escriba un tipo de movimiento valido';
			ROLLBACK;
		WHEN OTHERS THEN
			RAISE NOTICE 'Ha sucedido algun error';
			ROLLBACK;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER up_cuenta
BEFORE INSERT
ON movimientos
for each row
execute procedure update_cuenta();

/*
2.Crear trigger que añada una linea en movimientos cuando update en cuentas
*/

CREATE OR REPLACE FUNCTION anade_mov()
RETURNS TRIGGER
AS $$
DECLARE cambio decimal(7,2) := old.saldo - new.saldo;
BEGIN 
	IF cambio > 0 THEN
		INSERT INTO movimientos (tipo,monto,id_cuenta) VALUES ('ingreso',cambio,new.id_cuenta);
	ELSEIF cambio < 0 THEN
		INSERT INTO movimientos (tipo,monto,id_cuenta) VALUES ('retiro',cambio,new.id_cuenta);
	END IF;
	RETURN new;
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE TRIGGER tr_anade_mov
AFTER UPDATE 
ON cuentas
FOR EACH ROW
EXECUTE FUNCTION anade_mov();

UPDATE cuentas SET saldo = 1200 WHERE id_cuenta = 1;

SELECT * FROM cuentas;
SELECT * FROM movimientos;