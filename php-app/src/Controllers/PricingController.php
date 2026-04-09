<?php

declare(strict_types=1);

namespace App\Controllers;

class PricingController
{
    private array $config;

    public function __construct(array $config)
    {
        $this->config = $config;
    }

    public function index(): void
    {
        $data = [
            'config' => $this->config,
            'title'  => 'Pricing',
        ];

        extract($data);
        $content = BASE_PATH . '/views/pricing/index.php';

        if (file_exists($content)) {
            require $content;
        }
    }
}
