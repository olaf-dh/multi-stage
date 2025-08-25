<?php

namespace App\Controller;

use Doctrine\DBAL\Connection;
use Doctrine\DBAL\Exception;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

class HomeController extends AbstractController
{
    #[Route('/', name: 'home')]
    public function index(): Response
    {
        return $this->render('home/index.html.twig', [
            'controller_name' => 'HomeController',
        ]);
    }

    #[Route('/health', name: 'health')]
    public function health(Connection $conn): JsonResponse
    {
        try {
            $conn->executeQuery('SELECT 1')->fetchOne();
            $db = 'up';
        } catch (\Throwable $e) {
            $db = 'down';
        }

        return $this->json(['app' => 'up', 'db' => $db]);
    }
}
