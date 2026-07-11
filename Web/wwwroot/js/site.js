// Please see documentation at https://docs.microsoft.com/aspnet/core/client-side/bundling-and-minification
// for details on configuring this project to bundle and minify static web assets.

// Keyboard navigation for messages pagination using Left and Right arrow keys
document.addEventListener('keydown', function (e) {
    // Ignore keydown events inside editable elements or input fields
    if (document.activeElement && (
        document.activeElement.tagName === 'INPUT' ||
        document.activeElement.tagName === 'TEXTAREA' ||
        document.activeElement.tagName === 'SELECT' ||
        document.activeElement.isContentEditable
    )) {
        return;
    }

    if (e.key === 'ArrowLeft') {
        var prevLink = document.querySelector('.prev-page-link');
        if (prevLink && !prevLink.closest('.page-item').classList.contains('disabled')) {
            var href = prevLink.getAttribute('href');
            if (href) {
                window.location.href = href;
            }
        }
    } else if (e.key === 'ArrowRight') {
        var nextLink = document.querySelector('.next-page-link');
        if (nextLink && !nextLink.closest('.page-item').classList.contains('disabled')) {
            var href = nextLink.getAttribute('href');
            if (href) {
                window.location.href = href;
            }
        }
    }
});
