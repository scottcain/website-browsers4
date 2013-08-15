<?php
$headers = 'From: no-reply@wormbase.org';
mail('no-reply@wormbase.org', 'Test email from SES', "Testbody \n Some more lines.", $headers);
?>