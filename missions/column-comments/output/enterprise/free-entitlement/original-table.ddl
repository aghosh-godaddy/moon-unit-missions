
CREATE TABLE free_entitlement(
	entitlement_id 							string,
	resource_id 							int,
	product_type_id 						int,
	product_family_name 						string,
	free_pf_id 							int,
	free_type_name 							string,
	free_bill_id 							string,
	free_bill_line_num 						int,
	free_bill_mst_ts 						timestamp,
	free_bill_mst_date 						date,
	free_bill_type_name 						string,
	free_target_expiration_mst_ts 					timestamp,
	free_target_expiration_mst_date 				date,
	free_acquisition_mst_ts 					timestamp,
	free_acquisition_mst_date 					date,
	paid_pf_id 							int,
	paid_bill_id 							string,
	paid_bill_line_num 						int,
	paid_bill_mst_ts 						timestamp,
	paid_bill_mst_date 						date,
	etl_build_mst_ts 						timestamp
);

