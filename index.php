<?php
header('Content-Type: application/json');
echo json_encode(['current_time' => gmdate('Y-m-d H:i:s')]);
?>
