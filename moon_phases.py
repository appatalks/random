## Proof of concept to show moon phases. Use YYYY-MM-DD. 
## Not accurate, simplistic.

import pygame
import math
import datetime

# Colors
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
GRAY = (200, 200, 200)
BLUE = (0, 0, 255)

# Window size
WIDTH = 800
HEIGHT = 400

# Initialize Pygame
pygame.init()
window = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Moon Phases")

# Font
font = pygame.font.Font(None, 36)

# Input box
input_box = pygame.Rect(50, 50, 200, 32)
input_text = ""

# Get the current date
current_date = datetime.datetime.now()

# Calculate the phase of the moon
def calculate_moon_phase(year, month, day):
    ages = [18, 0, 11, 22, 3, 14, 25, 6, 17, 28, 9, 20, 1, 12, 23, 4, 15, 26, 7]
    offsets = [-1, 1, 0, 1, 2, 3, 4, 5, 7, 7, 9, 9]
    description = ["New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous",
                   "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent"]

    if day == 31:
        day = 1

    days_into_phase = ((ages[(year + 1) % 19] +
                        ((day + offsets[month-1]) % 30) +
                        (year < 1900)) % 30)
    index = int((days_into_phase + 2) * 16/59.0)

    return index

# Cycle to the next moon phase
def cycle_moon_phase():
    global current_date
    current_date += datetime.timedelta(days=1)

# Main game loop
running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_RETURN:
                try:
                    input_date = datetime.datetime.strptime(input_text, "%Y-%m-%d")
                    current_date = input_date
                    input_text = ""
                except ValueError:
                    pass
            elif event.key == pygame.K_BACKSPACE:
                input_text = input_text[:-1]
            else:
                input_text += event.unicode
        if event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:
                # Check if the mouse click is on the button
                if pygame.Rect(WIDTH // 2 - 50, HEIGHT - 100, 100, 50).collidepoint(event.pos):
                    cycle_moon_phase()

    window.fill(GRAY)

    # Draw input box
    pygame.draw.rect(window, WHITE, input_box, 2)
    input_surface = font.render(input_text, True, WHITE)
    window.blit(input_surface, (input_box.x + 5, input_box.y + 5))

    # Get the current moon phase
    moon_phase = calculate_moon_phase(current_date.year, current_date.month, current_date.day)

    # Calculate the shadow width based on the phase
    shadow_width = WIDTH * (8 - moon_phase) // 16

    # Draw the shadowed portion of the moon
    pygame.draw.ellipse(window, BLACK, (WIDTH // 2 - shadow_width // 2, HEIGHT // 4, shadow_width, HEIGHT // 2))

    # Draw moon phase text
    phase_text = font.render("Moon Phase: " + str(moon_phase), True, BLUE)
    window.blit(phase_text, (WIDTH // 2 - phase_text.get_width() // 2, HEIGHT // 2 + 50))

    # Draw button
    pygame.draw.rect(window, WHITE, (WIDTH // 2 - 50, HEIGHT - 100, 100, 50))
    button_text = font.render("Next", True, BLACK)
    window.blit(button_text, (WIDTH // 2 - button_text.get_width() // 2, HEIGHT - 85))

    pygame.display.flip()

pygame.quit()
